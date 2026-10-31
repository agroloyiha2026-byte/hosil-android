-- Disposable/test project only; final exception rolls back all fixtures.
do $$
declare
  v_owner uuid;
  v_other uuid;
  v_goal uuid;
  v_count integer;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select id into v_owner from public.profiles where role <> 'admin' limit 1;
  select id into v_other from public.profiles where id <> v_owner and role <> 'admin' limit 1;
  if v_owner is null or v_other is null then
    raise exception 'Test needs two non-admin profiles';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  execute 'set local role authenticated';
  insert into public.user_goals (user_id, title, category, progress_mode)
    values (v_owner, 'migration19-rls-goal', 'personal', 'tasks')
    returning id into v_goal;
  select count(*) into v_count from public.user_goal_events
    where goal_id = v_goal and user_id = v_owner;
  v_results := v_results || jsonb_build_object('test', 'goal creation is recorded in owner history', 'ok', v_count = 1);

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.user_goals where id = v_goal;
  v_results := v_results || jsonb_build_object('test', 'another user cannot read a goal', 'ok', v_count = 0);
  update public.user_goals set title = 'attempted-takeover' where id = v_goal;
  get diagnostics v_count = row_count;
  v_results := v_results || jsonb_build_object('test', 'another user cannot update a goal', 'ok', v_count = 0);
  select count(*) into v_count from public.user_goal_events where goal_id = v_goal;
  v_results := v_results || jsonb_build_object('test', 'another user cannot read goal history', 'ok', v_count = 0);

  execute 'reset role';
  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 19 universal-goal RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
