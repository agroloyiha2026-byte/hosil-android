-- Expand banner destinations without changing existing banner rows or columns.
-- link_value remains the destination identifier/value for backward compatibility.
-- Apply manually after migration 19.

alter table public.banners drop constraint if exists banners_link_type_check;
alter table public.banners add constraint banners_link_type_check
  check (link_type in (
    'none', 'product', 'category', 'url', 'agroapteka', 'warehouse', 'equipment', 'logistics'
  ));
