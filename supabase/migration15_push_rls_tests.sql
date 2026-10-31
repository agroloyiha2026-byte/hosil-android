-- Disposable/test project only; final exception rolls back token fixtures.
do $$
declare
  v_owner uuid;
  v_other uuid;
  v_token text := 'rls-test-token-' || gen_random_uuid()::text;
  v_count integer;
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
  perform public.register_device_token(v_token, 'android');
  begin
    select count(*) into v_count from public.device_tokens;
    v_results := v_results || jsonb_build_object('test', 'client cannot read device tokens', 'ok', false);
  exception when insufficient_privilege then
    v_results := v_results || jsonb_build_object('test', 'client cannot read device tokens', 'ok', true);
  end;
  begin
    insert into public.device_tokens (token, user_id, platform)
      values ('direct-write-' || gen_random_uuid()::text, v_owner, 'android');
    v_results := v_results || jsonb_build_object('test', 'client cannot write token table directly', 'ok', false);
  exception when insufficient_privilege then
    v_results := v_results || jsonb_build_object('test', 'client cannot write token table directly', 'ok', true);
  end;
  begin
    perform public.claim_push_delivery(gen_random_uuid());
    v_results := v_results || jsonb_build_object('test', 'client cannot claim push delivery', 'ok', false);
  exception when insufficient_privilege then
    v_results := v_results || jsonb_build_object('test', 'client cannot claim push delivery', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  execute 'set local role authenticated';
  perform public.unregister_device_token(v_token);
  execute 'reset role';

  select count(*) into v_count from public.device_tokens
    where token = v_token and user_id = v_owner;
  v_results := v_results || jsonb_build_object('test', 'other account cannot unregister token', 'ok', v_count = 1);

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  execute 'set local role authenticated';
  perform public.unregister_device_token(v_token);
  execute 'reset role';
  select count(*) into v_count from public.device_tokens where token = v_token;
  v_results := v_results || jsonb_build_object('test', 'owner can unregister own token', 'ok', v_count = 0);

  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 15 push RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
