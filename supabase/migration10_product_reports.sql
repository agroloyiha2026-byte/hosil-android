-- Additive policy for authenticated users to report a product using the existing
-- reports table contract (product_id, reason, resolved). No existing policies or
-- columns are removed or replaced.
alter table public.reports enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'reports'
      and policyname = 'reports: authenticated users submit'
  ) then
    create policy "reports: authenticated users submit"
      on public.reports for insert to authenticated
      with check (
        auth.uid() is not null
        and exists (select 1 from public.products p where p.id = product_id)
      );
  end if;
end $$;
