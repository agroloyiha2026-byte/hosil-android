-- Additive listing media support. Existing listings keep their current values.
alter table public.service_listings
  add column if not exists image_url text;

create or replace function public.service_listings_require_image_on_publish()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.status = 'active' and nullif(trim(new.image_url), '') is null then
    raise exception 'service listing image required';
  end if;
  return new;
end;
$$;

drop trigger if exists zz_service_listing_image_guard on public.service_listings;
create trigger zz_service_listing_image_guard
  before insert or update on public.service_listings
  for each row execute function public.service_listings_require_image_on_publish();