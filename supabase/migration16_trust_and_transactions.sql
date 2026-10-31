-- Phone verification remains in auth.users.phone_confirmed_at. Never trust
-- profiles.phone or a client-supplied verification flag.
create table if not exists public.seller_verifications (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

alter table public.seller_verifications enable row level security;
revoke all on public.seller_verifications from anon, authenticated;
grant select on public.seller_verifications to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'seller_verifications'
      and policyname = 'seller verification: own or admin read'
  ) then
    create policy "seller verification: own or admin read"
      on public.seller_verifications for select to authenticated
      using (user_id = auth.uid() or public.is_admin());
  end if;
end $$;

create or replace function public.request_seller_verification()
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  if not exists (
    select 1 from auth.users
    where id = auth.uid() and phone_confirmed_at is not null
  ) then
    raise exception 'phone_not_verified';
  end if;
  insert into public.seller_verifications (user_id, status, requested_at, reviewed_at, reviewed_by)
  values (auth.uid(), 'pending', now(), null, null)
  on conflict (user_id) do update
    set status = 'pending', requested_at = now(), reviewed_at = null, reviewed_by = null
    where public.seller_verifications.status = 'rejected';

  select status into v_status
    from public.seller_verifications where user_id = auth.uid();
  return v_status;
end $$;

create or replace function public.review_seller_verification(p_user_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('verified', 'rejected') then raise exception 'invalid_status'; end if;
  update public.seller_verifications
    set status = p_status, reviewed_at = now(), reviewed_by = auth.uid()
    where user_id = p_user_id and status = 'pending';
  if not found then raise exception 'verification_request_not_found'; end if;
end $$;

revoke all on function public.request_seller_verification() from public, anon;
revoke all on function public.review_seller_verification(uuid, text) from public, anon;
grant execute on function public.request_seller_verification() to authenticated;
grant execute on function public.review_seller_verification(uuid, text) to authenticated;

create or replace function public.audit_seller_verification_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (
      coalesce(auth.uid(), new.reviewed_by),
      case when tg_op = 'INSERT' then 'request' else 'review' end,
      'seller_verification',
      new.user_id::text,
      jsonb_build_object(
        'status', new.status,
        'requested_at', new.requested_at,
        'reviewed_by', new.reviewed_by
      )
    );
  end if;
  return new;
end $$;

drop trigger if exists seller_verifications_audit on public.seller_verifications;
create trigger seller_verifications_audit
  after insert or update of status on public.seller_verifications
  for each row execute function public.audit_seller_verification_change();

-- This ledger is intentionally unusable by mobile clients until a real payment
-- provider and a server-verified webhook have been deployed and reviewed.
create table if not exists public.secure_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  buyer_id uuid not null references public.profiles(id) on delete restrict,
  seller_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(18, 2) not null check (amount > 0),
  currency text not null check (currency in ('UZS', 'USD')),
  status text not null default 'created'
    check (status in (
      'created', 'payment_pending', 'payment_confirmed', 'in_delivery',
      'buyer_confirmed', 'released', 'cancelled', 'refunded',
      'dispute_open', 'dispute_review'
    )),
  provider text,
  provider_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint secure_transactions_distinct_parties check (buyer_id <> seller_id)
);

create index if not exists secure_transactions_buyer_idx
  on public.secure_transactions (buyer_id, created_at desc);
create index if not exists secure_transactions_seller_idx
  on public.secure_transactions (seller_id, created_at desc);

alter table public.secure_transactions enable row level security;
revoke all on public.secure_transactions from anon, authenticated;
grant select on public.secure_transactions to authenticated;
grant select, insert, update on public.secure_transactions to service_role;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'secure_transactions'
      and policyname = 'secure transactions: participants read'
  ) then
    create policy "secure transactions: participants read"
      on public.secure_transactions for select to authenticated
      using (buyer_id = auth.uid() or seller_id = auth.uid() or public.is_admin());
  end if;
end $$;

create table if not exists public.secure_transaction_events (
  id bigint generated always as identity primary key,
  transaction_id uuid not null references public.secure_transactions(id) on delete restrict,
  from_status text,
  to_status text not null,
  actor_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.secure_transaction_events enable row level security;
revoke all on public.secure_transaction_events from anon, authenticated;
grant select on public.secure_transaction_events to authenticated;
grant select on public.secure_transaction_events to service_role;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'secure_transaction_events'
      and policyname = 'transaction events: participants read'
  ) then
    create policy "transaction events: participants read"
      on public.secure_transaction_events for select to authenticated
      using (exists (
        select 1 from public.secure_transactions t
        where t.id = transaction_id
          and (t.buyer_id = auth.uid() or t.seller_id = auth.uid() or public.is_admin())
      ));
  end if;
end $$;

create or replace function public.guard_secure_transaction_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'created' then raise exception 'invalid_initial_status'; end if;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.buyer_id is distinct from old.buyer_id
    or new.seller_id is distinct from old.seller_id
    or new.product_id is distinct from old.product_id
    or new.amount is distinct from old.amount
    or new.currency is distinct from old.currency
  then
    raise exception 'transaction_terms_immutable';
  end if;

  if new.status is distinct from old.status and not (
    (old.status = 'created' and new.status in ('payment_pending', 'cancelled'))
    or (old.status = 'payment_pending' and new.status in ('payment_confirmed', 'cancelled', 'refunded'))
    or (old.status = 'payment_confirmed' and new.status in ('in_delivery', 'dispute_open', 'refunded'))
    or (old.status = 'in_delivery' and new.status in ('buyer_confirmed', 'dispute_open'))
    or (old.status = 'buyer_confirmed' and new.status in ('released', 'dispute_open'))
    or (old.status = 'dispute_open' and new.status = 'dispute_review')
    or (old.status = 'dispute_review' and new.status in ('released', 'refunded'))
  ) then
    raise exception 'invalid_transaction_transition';
  end if;

  new.updated_at := now();
  return new;
end $$;

create or replace function public.record_secure_transaction_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;
  insert into public.secure_transaction_events
    (transaction_id, from_status, to_status, actor_id)
  values (
    new.id,
    case when tg_op = 'INSERT' then null else old.status end,
    new.status,
    auth.uid()
  );
  return new;
end $$;

drop trigger if exists secure_transactions_guard on public.secure_transactions;
create trigger secure_transactions_guard
  before insert or update on public.secure_transactions
  for each row execute function public.guard_secure_transaction_transition();
drop trigger if exists secure_transactions_event on public.secure_transactions;
create trigger secure_transactions_event
  after insert or update of status on public.secure_transactions
  for each row execute function public.record_secure_transaction_event();
