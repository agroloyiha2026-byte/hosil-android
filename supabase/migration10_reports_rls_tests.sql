-- Disposable/test project only; final exception rolls back the report fixture.
do $$
declare
  v_user uuid;
  v_product uuid;
  v_marker text := 'migration10-rls-' || gen_random_uuid()::text;
  v_count integer;
  v_resolved boolean;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select id into v_user from public.profiles where role <> 'admin' limit 1;
  select id into v_product from public.products limit 1;
  if v_user is null or v_product is null then
    raise exception 'Test needs a non-admin profile and a product';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_user::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.reports (product_id, reason) values (v_product, v_marker);
    v_results := v_results || jsonb_build_object('test', 'authenticated user can submit product report', 'ok', true);
  exception when others then
    v_results := v_results || jsonb_build_object(
      'test', 'authenticated user can submit product report', 'ok', false, 'detail', sqlerrm);
  end;
  begin
    update public.reports set resolved = true
      where product_id = v_product and reason = v_marker;
    get diagnostics v_count = row_count;
    v_results := v_results || jsonb_build_object('test', 'reporter cannot resolve reports', 'ok', v_count = 0);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'reporter cannot resolve reports', 'ok', true);
  end;
  execute 'reset role';

  select resolved into v_resolved from public.reports
    where product_id = v_product and reason = v_marker limit 1;
  v_results := v_results || jsonb_build_object(
    'test', 'report remains unresolved after client update attempt',
    'ok', v_resolved is distinct from true
  );

  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 10 report RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
