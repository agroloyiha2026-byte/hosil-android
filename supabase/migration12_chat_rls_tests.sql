-- Disposable/test project only; requires one existing inquiry and an outsider.
-- Final exception rolls back the message fixture and read marker.
do $$
declare
  v_inquiry uuid;
  v_buyer uuid;
  v_seller uuid;
  v_outsider uuid;
  v_count integer;
  v_marker text := 'migration12-rls-' || gen_random_uuid()::text;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select i.id, i.buyer_id, p.seller_id
    into v_inquiry, v_buyer, v_seller
    from public.inquiries i
    join public.products p on p.id = i.product_id
    where i.buyer_id <> p.seller_id
    limit 1;
  select id into v_outsider from public.profiles
    where id not in (v_buyer, v_seller) and role <> 'admin' limit 1;
  if v_inquiry is null or v_outsider is null then
    raise exception 'Test needs an inquiry with distinct buyer/seller and an outsider';
  end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_seller::text, true);
  execute 'set local role authenticated';
  insert into public.chat_messages (inquiry_id, sender_id, body)
    values (v_inquiry, v_seller, v_marker);
  select count(*) into v_count from public.chat_messages
    where inquiry_id = v_inquiry and body = v_marker;
  v_results := v_results || jsonb_build_object('test', 'inquiry participant reads message', 'ok', v_count = 1);
  begin
    update public.chat_messages set body = 'tampered'
      where inquiry_id = v_inquiry and body = v_marker;
    v_results := v_results || jsonb_build_object('test', 'sender cannot rewrite message body', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'sender cannot rewrite message body', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outsider, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_outsider::text, true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.chat_messages
    where inquiry_id = v_inquiry and body = v_marker;
  v_results := v_results || jsonb_build_object('test', 'outsider cannot read chat message', 'ok', v_count = 0);
  begin
    insert into public.chat_messages (inquiry_id, sender_id, body)
      values (v_inquiry, v_outsider, 'unauthorized');
    v_results := v_results || jsonb_build_object('test', 'outsider cannot send chat message', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'outsider cannot send chat message', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_buyer, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_buyer::text, true);
  execute 'set local role authenticated';
  update public.chat_messages
    set read_by = v_buyer, read_at = now()
    where inquiry_id = v_inquiry and body = v_marker;
  get diagnostics v_count = row_count;
  v_results := v_results || jsonb_build_object('test', 'recipient can mark incoming message read', 'ok', v_count = 1);

  execute 'reset role';
  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 12 chat RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
