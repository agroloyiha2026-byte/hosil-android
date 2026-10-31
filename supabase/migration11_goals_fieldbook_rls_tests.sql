-- Disposable/test project only; final exception rolls back all fixtures.
do $$
declare
  v_owner uuid;
  v_other uuid;
  v_goal uuid;
  v_entry uuid := gen_random_uuid();
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
  insert into public.financial_goals (user_id, title, target_amount)
    values (v_owner, 'migration11-rls-goal', 100)
    returning id into v_goal;
  perform public.sync_fieldbook_entry(
    v_entry,
    now(),
    jsonb_build_object(
      'crop_type', 'migration11-test',
      'activity_type', 'note',
      'entry_date', current_date,
      'currency', 'UZS'
    )
  );
  select count(*) into v_count from public.financial_goals where id = v_goal;
  v_results := v_results || jsonb_build_object('test', 'goal owner reads own goal', 'ok', v_count = 1);
  select count(*) into v_count from public.fieldbook_entries where client_id = v_entry;
  v_results := v_results || jsonb_build_object('test', 'fieldbook owner reads synced entry', 'ok', v_count = 1);
  begin
    insert into public.fieldbook_entries (
      client_id, user_id, crop_type, activity_type, entry_date
    ) values (gen_random_uuid(), v_owner, 'direct-write', 'note', current_date);
    v_results := v_results || jsonb_build_object('test', 'fieldbook rejects direct table write', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'fieldbook rejects direct table write', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_other::text, true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.financial_goals where id = v_goal;
  v_results := v_results || jsonb_build_object('test', 'other user cannot read goal', 'ok', v_count = 0);
  update public.financial_goals set title = 'attempted-takeover' where id = v_goal;
  get diagnostics v_count = row_count;
  v_results := v_results || jsonb_build_object('test', 'other user cannot update goal', 'ok', v_count = 0);
  select count(*) into v_count from public.fieldbook_entries where client_id = v_entry;
  v_results := v_results || jsonb_build_object('test', 'other user cannot read fieldbook entry', 'ok', v_count = 0);
  begin
    perform public.sync_fieldbook_entry(
      v_entry,
      now() + interval '1 second',
      jsonb_build_object(
        'crop_type', 'attempted-takeover',
        'activity_type', 'note',
        'entry_date', current_date,
        'currency', 'UZS'
      )
    );
    v_results := v_results || jsonb_build_object('test', 'other user cannot overwrite fieldbook entry', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'other user cannot overwrite fieldbook entry', 'ok', true);
  end;

  execute 'reset role';
  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 11 goals/fieldbook RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
