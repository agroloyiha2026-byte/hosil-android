-- Server-issued public identifiers for product information cards.
-- These passports do not certify quality, laboratory results, or origin.
create table if not exists public.harvest_passports (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references public.products(id) on delete set null,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  issued_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index if not exists harvest_passports_one_active_product_idx
  on public.harvest_passports (product_id)
  where product_id is not null and revoked_at is null;
create index if not exists harvest_passports_owner_issued_idx
  on public.harvest_passports (owner_id, issued_at desc);

alter table public.harvest_passports enable row level security;
revoke all on public.harvest_passports from anon, authenticated;
grant select on public.harvest_passports to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public'
      and tablename = 'harvest_passports' and policyname = 'harvest passports: owner and admin read'
  ) then
    create policy "harvest passports: owner and admin read"
      on public.harvest_passports for select to authenticated
      using (owner_id = auth.uid() or public.is_admin());
  end if;
end $$;

create or replace function public.create_harvest_passport(p_product_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_passport_id uuid;
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;

  if not exists (
    select 1 from public.products p
    where p.id = p_product_id
      and p.seller_id = auth.uid()
      and p.status = 'active'
      and p.moderation_status = 'approved'
  ) then
    raise exception 'product_not_eligible';
  end if;

  insert into public.harvest_passports (product_id, owner_id)
  values (p_product_id, auth.uid())
  on conflict (product_id) where product_id is not null and revoked_at is null
  do nothing
  returning id into v_passport_id;

  if v_passport_id is null then
    select id into v_passport_id from public.harvest_passports
      where product_id = p_product_id and revoked_at is null;
  end if;

  return v_passport_id;
end $$;

create or replace function public.revoke_harvest_passport(p_passport_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  update public.harvest_passports
    set revoked_at = now()
    where id = p_passport_id and owner_id = auth.uid() and revoked_at is null;
  if not found then raise exception 'passport_not_found_or_already_revoked'; end if;
end $$;

create or replace function public.my_harvest_passports()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', hp.id,
      'product_id', hp.product_id,
      'issued_at', hp.issued_at,
      'revoked_at', hp.revoked_at,
      'product_title', p.title,
      'product_type', p.product_type,
      'category', p.category,
      'product_region', p.region,
      'farmer_name', pr.full_name,
      'farmer_region', pr.region,
      'product_public', coalesce(p.status = 'active' and p.moderation_status = 'approved', false)
    ) order by hp.issued_at desc
  ), '[]'::jsonb)
  from public.harvest_passports hp
  left join public.products p on p.id = hp.product_id
  join public.profiles pr on pr.id = hp.owner_id
  where hp.owner_id = auth.uid();
$$;

create or replace function public.verify_harvest_passport(p_public_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'id', hp.id,
    'issued_at', hp.issued_at,
    'status', case
      when hp.revoked_at is not null then 'revoked'
      when p.id is null or p.status <> 'active' or p.moderation_status <> 'approved' then 'unavailable'
      else 'active'
    end,
    'revoked_at', hp.revoked_at,
    'product_title', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then p.title end,
    'product_type', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then p.product_type end,
    'category', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then p.category end,
    'product_region', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then p.region end,
    'farmer_name', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then pr.full_name end,
    'farmer_region', case when hp.revoked_at is null and p.status = 'active' and p.moderation_status = 'approved' then pr.region end,
    'quality_certified', false
  )
  from public.harvest_passports hp
  left join public.products p on p.id = hp.product_id
  left join public.profiles pr on pr.id = hp.owner_id
  where hp.id = p_public_id;
$$;

create or replace function public.audit_harvest_passport_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.audit_logs (actor_id, action, entity, entity_id, details)
  values (
    coalesce(auth.uid(), new.owner_id),
    case when tg_op = 'INSERT' then 'create' else 'revoke' end,
    'harvest_passport',
    new.id::text,
    jsonb_build_object('product_id', new.product_id, 'revoked_at', new.revoked_at)
  );
  return new;
end $$;

drop trigger if exists harvest_passport_audit on public.harvest_passports;
create trigger harvest_passport_audit
  after insert or update of revoked_at on public.harvest_passports
  for each row execute function public.audit_harvest_passport_change();

revoke all on function public.create_harvest_passport(uuid) from public, anon;
revoke all on function public.revoke_harvest_passport(uuid) from public, anon;
revoke all on function public.my_harvest_passports() from public, anon;
revoke all on function public.verify_harvest_passport(uuid) from public;

grant execute on function public.create_harvest_passport(uuid) to authenticated;
grant execute on function public.revoke_harvest_passport(uuid) to authenticated;
grant execute on function public.my_harvest_passports() to authenticated;
grant execute on function public.verify_harvest_passport(uuid) to anon, authenticated;
