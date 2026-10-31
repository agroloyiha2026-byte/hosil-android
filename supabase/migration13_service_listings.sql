-- Equipment rental and logistics service listings with owner and admin RLS.
create table if not exists public.service_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  service_type text not null check (service_type in ('equipment', 'logistics')),
  title text not null check (length(trim(title)) between 3 and 120),
  region text not null,
  description text not null check (length(trim(description)) between 10 and 4000),
  price_amount numeric check (price_amount is null or price_amount >= 0),
  currency text not null default 'UZS' check (currency in ('UZS', 'USD')),
  price_unit text,
  contact_phone text,
  status text not null default 'pending' check (status in ('pending', 'active', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_listings_public_idx
  on public.service_listings (service_type, status, created_at desc);
create index if not exists service_listings_owner_idx
  on public.service_listings (owner_id, created_at desc);

create or replace function public.service_listings_before_write() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if not public.is_admin() then new.status := 'pending'; end if;
  else
    new.updated_at := now();
    if not public.is_admin() then
      if new.service_type is distinct from old.service_type
        or new.title is distinct from old.title
        or new.region is distinct from old.region
        or new.description is distinct from old.description
        or new.price_amount is distinct from old.price_amount
        or new.currency is distinct from old.currency
        or new.price_unit is distinct from old.price_unit
        or new.contact_phone is distinct from old.contact_phone then
        new.status := 'pending';
      else
        new.status := old.status;
      end if;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists service_listings_before_write on public.service_listings;
create trigger service_listings_before_write
  before insert or update on public.service_listings
  for each row execute function public.service_listings_before_write();

create or replace function public.audit_service_listing_status() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.status is distinct from old.status then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'service_listing_status', 'service_listing', new.id::text,
      jsonb_build_object('from', old.status, 'to', new.status, 'service_type', new.service_type));
  end if;
  return new;
end $$;

drop trigger if exists service_listing_status_audit on public.service_listings;
create trigger service_listing_status_audit
  after update of status on public.service_listings
  for each row execute function public.audit_service_listing_status();

alter table public.service_listings enable row level security;
revoke all on public.service_listings from anon, authenticated;
grant select on public.service_listings to anon, authenticated;
grant insert, update, delete on public.service_listings to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'service_listings' and policyname = 'service listings: public and owner read'
  ) then
    create policy "service listings: public and owner read"
      on public.service_listings for select
      using (status = 'active' or owner_id = auth.uid() or public.is_admin());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'service_listings' and policyname = 'service listings: owner create'
  ) then
    create policy "service listings: owner create"
      on public.service_listings for insert to authenticated
      with check (owner_id = auth.uid() and status = 'pending');
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'service_listings' and policyname = 'service listings: owner update'
  ) then
    create policy "service listings: owner update"
      on public.service_listings for update to authenticated
      using (owner_id = auth.uid())
      with check (owner_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'service_listings' and policyname = 'service listings: owner delete inactive'
  ) then
    create policy "service listings: owner delete inactive"
      on public.service_listings for delete to authenticated
      using (owner_id = auth.uid() and status <> 'active');
  end if;

  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'service_listings' and policyname = 'service listings: admin manage'
  ) then
    create policy "service listings: admin manage"
      on public.service_listings for all to authenticated
      using (public.is_admin())
      with check (public.is_admin());
  end if;
end $$;
