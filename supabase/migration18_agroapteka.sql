-- Agroapteka catalog, owner workspace, inquiries, and administrator moderation.
-- Apply manually after migration 17, after reviewing the target schema.

create table if not exists public.agroapteka_categories (
  slug text primary key check (slug ~ '^[a-z0-9_]+$'),
  name_uz text not null,
  name_ru text not null,
  name_en text not null,
  active boolean not null default true,
  sort_order integer not null default 0
);

insert into public.agroapteka_categories (slug, name_uz, name_ru, name_en, sort_order) values
  ('seeds', 'Urug‘lar va ko‘chatlar', 'Семена и саженцы', 'Seeds and seedlings', 1),
  ('fertilizers', 'O‘g‘itlar', 'Удобрения', 'Fertilizers', 2),
  ('plant_protection', 'O‘simliklarni himoya qilish', 'Защита растений', 'Plant protection', 3),
  ('soil', 'Tuproq yaxshilagichlar', 'Улучшители почвы', 'Soil amendments', 4),
  ('irrigation', 'Sug‘orish jihozlari', 'Оборудование для полива', 'Irrigation equipment', 5),
  ('other', 'Boshqa agro mahsulotlar', 'Другие агротовары', 'Other agricultural supplies', 6)
on conflict (slug) do nothing;

create table if not exists public.agroapteka_stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 140),
  phone text not null check (length(trim(phone)) between 3 and 40),
  region text not null check (length(trim(region)) between 2 and 100),
  district text,
  address text not null check (length(trim(address)) between 3 and 300),
  latitude double precision,
  longitude double precision,
  location_public boolean not null default false,
  opening_hours text,
  image_url text,
  description text,
  delivery_enabled boolean not null default false,
  delivery_area text,
  order_info text,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  is_verified boolean not null default false,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or
    (latitude between -90 and 90 and longitude between -180 and 180)),
  check (not location_public or (latitude is not null and longitude is not null))
);

-- Emails, responsible-person details, and submitted document references are
-- deliberately separated from the public store record.
create table if not exists public.agroapteka_store_private (
  store_id uuid primary key references public.agroapteka_stores(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  company_name text,
  responsible_person text,
  email text,
  legal_document_url text,
  latitude double precision,
  longitude double precision,
  admin_note text,
  updated_at timestamptz not null default now()
);

create table if not exists public.agroapteka_products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.agroapteka_stores(id) on delete cascade,
  title text not null check (length(trim(title)) between 2 and 160),
  category text not null references public.agroapteka_categories(slug) on update cascade on delete restrict,
  description text,
  image_url text,
  price numeric(18, 2) not null check (price >= 0 and price <> 'NaN'::numeric),
  currency text not null default 'UZS' check (currency in ('UZS', 'USD')),
  unit text not null check (length(trim(unit)) between 1 and 32),
  stock numeric(18, 3) not null default 0 check (stock >= 0 and stock <> 'NaN'::numeric),
  manufacturer text,
  package_size text,
  expiry_date date,
  active_ingredient text,
  instructions_url text,
  storage_conditions text,
  safety_warning text,
  published boolean not null default false,
  moderation_status text not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected', 'blocked')),
  moderation_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agroapteka_inquiries (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.agroapteka_stores(id) on delete cascade,
  product_id uuid not null references public.agroapteka_products(id) on delete restrict,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  quantity numeric(18, 3) not null check (quantity > 0 and quantity <> 'NaN'::numeric),
  message text,
  status text not null default 'new'
    check (status in ('new', 'reviewing', 'accepted', 'rejected', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agroapteka_inquiry_messages (
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null references public.agroapteka_inquiries(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists public.agroapteka_reports (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.agroapteka_stores(id) on delete cascade,
  product_id uuid references public.agroapteka_products(id) on delete set null,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (length(trim(reason)) between 5 and 2000),
  status text not null default 'open' check (status in ('open', 'resolved')),
  admin_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists agroapteka_stores_public_idx
  on public.agroapteka_stores (region, status, is_verified);
create index if not exists agroapteka_products_public_idx
  on public.agroapteka_products (category, moderation_status, published, price);
create index if not exists agroapteka_products_store_idx
  on public.agroapteka_products (store_id, created_at desc);
create index if not exists agroapteka_inquiries_store_idx
  on public.agroapteka_inquiries (store_id, status, created_at desc);
create index if not exists agroapteka_inquiries_customer_idx
  on public.agroapteka_inquiries (customer_id, created_at desc);
create index if not exists agroapteka_inquiry_messages_thread_idx
  on public.agroapteka_inquiry_messages (inquiry_id, created_at);
create index if not exists agroapteka_reports_open_idx
  on public.agroapteka_reports (status, created_at desc);

create or replace function public.agroapteka_store_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'UPDATE' then
    new.updated_at := now();
    if not public.is_admin() then
      if new.owner_id is distinct from old.owner_id then raise exception 'owner_id_immutable'; end if;
      new.status := old.status;
      new.is_verified := old.is_verified;
      new.admin_note := old.admin_note;
      if new.name is distinct from old.name or new.address is distinct from old.address
        or new.region is distinct from old.region or new.district is distinct from old.district
        or new.latitude is distinct from old.latitude or new.longitude is distinct from old.longitude
        or new.location_public is distinct from old.location_public then
        new.status := 'pending';
        new.is_verified := false;
      end if;
    end if;
  else
    if not public.is_admin() then
      new.status := 'pending';
      new.is_verified := false;
      new.admin_note := null;
    end if;
  end if;
  if not new.location_public then
    new.latitude := null;
    new.longitude := null;
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_store_before_write on public.agroapteka_stores;
create trigger agroapteka_store_before_write before insert or update
  on public.agroapteka_stores for each row execute function public.agroapteka_store_before_write();

create or replace function public.agroapteka_private_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_admin() then
    if not exists (
      select 1 from public.agroapteka_stores s
      where s.id = new.store_id and s.owner_id = auth.uid() and new.owner_id = auth.uid()
    ) then raise exception 'forbidden'; end if;
    if tg_op = 'UPDATE' then
      if new.owner_id is distinct from old.owner_id then raise exception 'owner_id_immutable'; end if;
      new.admin_note := old.admin_note;
    else
      new.admin_note := null;
    end if;
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists agroapteka_private_before_write on public.agroapteka_store_private;
create trigger agroapteka_private_before_write before insert or update
  on public.agroapteka_store_private for each row execute function public.agroapteka_private_before_write();

create or replace function public.agroapteka_product_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare store_owner uuid;
begin
  select owner_id into store_owner from public.agroapteka_stores where id = new.store_id;
  if store_owner is null then raise exception 'store_not_found'; end if;
  if not public.is_admin() and store_owner <> auth.uid() then raise exception 'forbidden'; end if;
  if tg_op = 'UPDATE' then
    if new.store_id is distinct from old.store_id then raise exception 'store_id_immutable'; end if;
    new.updated_at := now();
    if not public.is_admin() then
      new.moderation_status := old.moderation_status;
      new.moderation_note := old.moderation_note;
      if new.title is distinct from old.title or new.category is distinct from old.category
        or new.description is distinct from old.description or new.image_url is distinct from old.image_url
        or new.price is distinct from old.price or new.currency is distinct from old.currency
        or new.unit is distinct from old.unit or new.stock is distinct from old.stock
        or new.manufacturer is distinct from old.manufacturer or new.package_size is distinct from old.package_size
        or new.expiry_date is distinct from old.expiry_date
        or new.active_ingredient is distinct from old.active_ingredient
        or new.instructions_url is distinct from old.instructions_url
        or new.storage_conditions is distinct from old.storage_conditions
        or new.safety_warning is distinct from old.safety_warning then
        new.moderation_status := 'pending';
      end if;
    end if;
  elsif not public.is_admin() then
    new.moderation_status := 'pending';
    new.moderation_note := null;
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_product_before_write on public.agroapteka_products;
create trigger agroapteka_product_before_write before insert or update
  on public.agroapteka_products for each row execute function public.agroapteka_product_before_write();

create or replace function public.agroapteka_inquiry_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null or new.customer_id <> auth.uid() then raise exception 'forbidden'; end if;
    if not exists (
      select 1 from public.agroapteka_products p
      join public.agroapteka_stores s on s.id = p.store_id
      where p.id = new.product_id and p.store_id = new.store_id
        and p.published and p.moderation_status = 'approved'
        and p.stock >= new.quantity and s.status = 'approved' and s.is_verified
    ) then raise exception 'product_unavailable'; end if;
    new.status := 'new';
    new.updated_at := now();
  else
    if new.store_id is distinct from old.store_id or new.product_id is distinct from old.product_id
      or new.customer_id is distinct from old.customer_id or new.quantity is distinct from old.quantity
      or new.message is distinct from old.message then raise exception 'inquiry_immutable'; end if;
    new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_inquiry_before_write on public.agroapteka_inquiries;
create trigger agroapteka_inquiry_before_write before insert or update
  on public.agroapteka_inquiries for each row execute function public.agroapteka_inquiry_before_write();

create or replace function public.audit_agroapteka_status()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'agroapteka_created', 'agroapteka_store', new.id::text,
      jsonb_build_object('status', new.status));
  elsif new.status is distinct from old.status or new.is_verified is distinct from old.is_verified then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'agroapteka_review', 'agroapteka_store', new.id::text,
      jsonb_build_object('from', old.status, 'to', new.status, 'verified', new.is_verified,
        'note', new.admin_note));
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_store_audit on public.agroapteka_stores;
create trigger agroapteka_store_audit after insert or update of status, is_verified
  on public.agroapteka_stores for each row execute function public.audit_agroapteka_status();

create or replace function public.audit_agroapteka_product_status()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' or new.moderation_status is distinct from old.moderation_status then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'agroapteka_product_review', 'agroapteka_product', new.id::text,
      jsonb_build_object('status', new.moderation_status, 'note', new.moderation_note));
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_product_audit on public.agroapteka_products;
create trigger agroapteka_product_audit after insert or update of moderation_status
  on public.agroapteka_products for each row execute function public.audit_agroapteka_product_status();

create or replace function public.audit_agroapteka_report_resolution()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (new.reporter_id, 'agroapteka_report_created', 'agroapteka_report', new.id::text,
      jsonb_build_object('store_id', new.store_id, 'product_id', new.product_id));
  elsif new.status is distinct from old.status then
    insert into public.audit_logs (actor_id, action, entity, entity_id, details)
    values (auth.uid(), 'agroapteka_report_resolved', 'agroapteka_report', new.id::text,
      jsonb_build_object('status', new.status, 'note', new.admin_note));
  end if;
  return new;
end $$;

create or replace function public.agroapteka_report_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_op = 'INSERT' and not public.is_admin() then
    if auth.uid() is null or new.reporter_id <> auth.uid() then raise exception 'forbidden'; end if;
    if new.product_id is not null and not exists (
      select 1 from public.agroapteka_products p
      where p.id = new.product_id and p.store_id = new.store_id
    ) then raise exception 'product_store_mismatch'; end if;
  end if;
  return new;
end $$;

drop trigger if exists agroapteka_report_before_write on public.agroapteka_reports;
create trigger agroapteka_report_before_write before insert
  on public.agroapteka_reports for each row execute function public.agroapteka_report_before_write();

drop trigger if exists agroapteka_report_audit on public.agroapteka_reports;
create trigger agroapteka_report_audit after insert or update of status
  on public.agroapteka_reports for each row execute function public.audit_agroapteka_report_resolution();

alter table public.agroapteka_categories enable row level security;
alter table public.agroapteka_stores enable row level security;
alter table public.agroapteka_store_private enable row level security;
alter table public.agroapteka_products enable row level security;
alter table public.agroapteka_inquiries enable row level security;
alter table public.agroapteka_inquiry_messages enable row level security;
alter table public.agroapteka_reports enable row level security;

revoke all on public.agroapteka_categories, public.agroapteka_stores,
  public.agroapteka_store_private, public.agroapteka_products,
  public.agroapteka_inquiries, public.agroapteka_inquiry_messages,
  public.agroapteka_reports from anon, authenticated;
grant select on public.agroapteka_categories, public.agroapteka_stores,
  public.agroapteka_products to anon, authenticated;
grant insert, update, delete on public.agroapteka_categories,
  public.agroapteka_stores, public.agroapteka_store_private,
  public.agroapteka_products, public.agroapteka_inquiries to authenticated;
grant insert, update on public.agroapteka_reports to authenticated;
grant select on public.agroapteka_reports to authenticated;
grant select on public.agroapteka_store_private,
  public.agroapteka_inquiries, public.agroapteka_inquiry_messages to authenticated;
grant insert on public.agroapteka_inquiry_messages to authenticated;
grant update on public.agroapteka_inquiries to authenticated;

create policy "agroapteka categories: active or admin"
  on public.agroapteka_categories for select
  using (active or public.is_admin());
create policy "agroapteka categories: admin manage"
  on public.agroapteka_categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "agroapteka stores: public or owner or admin"
  on public.agroapteka_stores for select
  using ((status = 'approved' and is_verified) or owner_id = auth.uid() or public.is_admin());
create policy "agroapteka stores: owner create"
  on public.agroapteka_stores for insert to authenticated
  with check (owner_id = auth.uid() and status = 'pending' and not is_verified);
create policy "agroapteka stores: owner update"
  on public.agroapteka_stores for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "agroapteka stores: admin manage"
  on public.agroapteka_stores for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "agroapteka private: owner or admin"
  on public.agroapteka_store_private for all to authenticated
  using (owner_id = auth.uid() or public.is_admin())
  with check ((owner_id = auth.uid() and exists (
    select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid()
  )) or public.is_admin());

create policy "agroapteka products: public or owner or admin"
  on public.agroapteka_products for select
  using ((published and moderation_status = 'approved' and exists (
    select 1 from public.agroapteka_stores s
    where s.id = store_id and s.status = 'approved' and s.is_verified
  )) or exists (
    select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid()
  ) or public.is_admin());
create policy "agroapteka products: owner create"
  on public.agroapteka_products for insert to authenticated
  with check (moderation_status = 'pending' and exists (
    select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid()
  ));
create policy "agroapteka products: owner update"
  on public.agroapteka_products for update to authenticated
  using (exists (select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin())
  with check (exists (select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin());
create policy "agroapteka products: owner delete"
  on public.agroapteka_products for delete to authenticated
  using (exists (select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin());

create policy "agroapteka inquiries: participants or admin read"
  on public.agroapteka_inquiries for select to authenticated
  using (customer_id = auth.uid() or exists (
    select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid()
  ) or public.is_admin());
create policy "agroapteka inquiries: customer create"
  on public.agroapteka_inquiries for insert to authenticated
  with check (customer_id = auth.uid());
create policy "agroapteka inquiries: store owner status update"
  on public.agroapteka_inquiries for update to authenticated
  using (exists (select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin())
  with check (exists (select 1 from public.agroapteka_stores s where s.id = store_id and s.owner_id = auth.uid())
    or public.is_admin());

create policy "agroapteka messages: inquiry participants read"
  on public.agroapteka_inquiry_messages for select to authenticated
  using (exists (
    select 1 from public.agroapteka_inquiries i
    where i.id = inquiry_id and (
      i.customer_id = auth.uid() or exists (
        select 1 from public.agroapteka_stores s where s.id = i.store_id and s.owner_id = auth.uid()
      ) or public.is_admin()
    )
  ));
create policy "agroapteka messages: participants send"
  on public.agroapteka_inquiry_messages for insert to authenticated
  with check (sender_id = auth.uid() and exists (
    select 1 from public.agroapteka_inquiries i
    where i.id = inquiry_id and (
      i.customer_id = auth.uid() or exists (
        select 1 from public.agroapteka_stores s where s.id = i.store_id and s.owner_id = auth.uid()
      ) or public.is_admin()
    )
  ));

create policy "agroapteka reports: submit own"
  on public.agroapteka_reports for insert to authenticated
  with check (reporter_id = auth.uid());
create policy "agroapteka reports: admin read and resolve"
  on public.agroapteka_reports for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.agroapteka_review_store(
  p_store_id uuid, p_status text, p_note text default null
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('approved', 'rejected', 'suspended') then raise exception 'invalid_status'; end if;
  update public.agroapteka_stores
    set status = p_status,
        is_verified = (p_status = 'approved'),
        admin_note = nullif(trim(p_note), '')
    where id = p_store_id;
  if not found then raise exception 'store_not_pending'; end if;
  update public.agroapteka_store_private
    set admin_note = nullif(trim(p_note), ''), updated_at = now()
    where store_id = p_store_id;
end $$;

create or replace function public.agroapteka_moderate_product(
  p_product_id uuid, p_status text, p_note text default null
) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'forbidden'; end if;
  if p_status not in ('approved', 'rejected', 'blocked') then raise exception 'invalid_status'; end if;
  update public.agroapteka_products
    set moderation_status = p_status, moderation_note = nullif(trim(p_note), '')
    where id = p_product_id;
  if not found then raise exception 'product_not_found'; end if;
end $$;

revoke all on function public.agroapteka_review_store(uuid, text, text),
  public.agroapteka_moderate_product(uuid, text, text) from public, anon;
grant execute on function public.agroapteka_review_store(uuid, text, text),
  public.agroapteka_moderate_product(uuid, text, text) to authenticated;
