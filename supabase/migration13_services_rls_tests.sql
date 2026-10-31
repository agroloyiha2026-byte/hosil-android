-- Disposable/test project only; final exception rolls back listing fixtures.
do $$
declare
  v_owner uuid;
  v_other uuid;
  v_listing uuid;
  v_marker text := 'migration13-rls-' || gen_random_uuid()::text;
  v_count integer;
  v_status text;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select id into v_owner from public.profiles where role <> 'admin' limit 1;
  select id into v_other from public.profiles
    where id <> v_owner and role <> 'admin' limit 1;
  if v_owner is null or v_other is null then
    raise exception 'Test needs two non-admin profiles';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  execute 'set local role authenticated';
  insert into public.service_listings (
    owner_id, service_type, title, region, description, status
  ) values (
    v_owner, 'equipment', v_marker, 'test', 'RLS test listing description', 'active'
  );
  select id into v_listing from public.service_listings where title = v_marker;
  select status into v_status from public.service_listings where id = v_listing;
  v_results := v_results || jsonb_build_object('test', 'new owner listing forced pending', 'ok', v_status = 'pending');
  update public.service_listings set status = 'active' where id = v_listing;
  select status into v_status from public.service_listings where id = v_listing;
  v_results := v_results || jsonb_build_object('test', 'owner cannot approve own listing', 'ok', v_status = 'pending');

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.service_listings where id = v_listing;
  v_results := v_results || jsonb_build_object('test', 'other user cannot read pending listing', 'ok', v_count = 0);
  update public.service_listings set title = 'unauthorized' where id = v_listing;
  get diagnostics v_count = row_count;
  v_results := v_results || jsonb_build_object('test', 'other user cannot edit listing', 'ok', v_count = 0);

  execute 'reset role';
  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 13 services RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
