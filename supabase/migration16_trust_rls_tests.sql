-- Run only in a disposable/test Supabase database after migration 16.
-- The final exception is intentional; the transaction rolls back all fixtures.
do $$
declare
  v_buyer uuid;
  v_seller uuid;
  v_outsider uuid;
  v_unverified uuid;
  v_admin uuid;
  v_product uuid;
  v_tx uuid;
  v_count integer;
  v_event_id bigint;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select p.id, p.seller_id
    into v_product, v_seller
    from public.products p
    join public.profiles seller on seller.id = p.seller_id
    where p.seller_id is not null and seller.role <> 'admin'
    limit 1;
  if v_product is null then raise exception 'Test needs at least one product'; end if;

  select id into v_buyer from public.profiles
    where id <> v_seller and role <> 'admin' limit 1;
  select id into v_outsider from public.profiles
    where id not in (v_seller, v_buyer) and role <> 'admin' limit 1;
  select id into v_admin from public.profiles where role = 'admin' limit 1;
  select p.id into v_unverified
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.role <> 'admin' and u.phone_confirmed_at is null
    limit 1;
  if v_buyer is null or v_outsider is null or v_unverified is null or v_admin is null then
    raise exception 'Test needs buyer, seller, outsider, admin, and unverified phone profiles';
  end if;

  insert into public.secure_transactions
    (product_id, buyer_id, seller_id, amount, currency)
  values (v_product, v_buyer, v_seller, 1, 'UZS')
  returning id into v_tx;
  insert into public.seller_verifications (user_id, status)
  values (v_buyer, 'pending')
  on conflict (user_id) do update set status = 'pending';

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_buyer, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_buyer::text, true);
  execute 'set local role authenticated';

  select count(*) into v_count from public.secure_transactions where id = v_tx;
  v_results := v_results || jsonb_build_object('test', 'buyer reads own transaction', 'ok', v_count = 1);
  select count(*) into v_count from public.secure_transaction_events
    where transaction_id = v_tx and to_status = 'created';
  v_results := v_results || jsonb_build_object('test', 'buyer reads own transaction events', 'ok', v_count = 1);
  select id into v_event_id from public.secure_transaction_events
    where transaction_id = v_tx and to_status = 'created' limit 1;
  begin
    update public.secure_transaction_events set to_status = 'payment_confirmed'
      where id = v_event_id;
    v_results := v_results || jsonb_build_object('test', 'buyer cannot edit audit event', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'buyer cannot edit audit event', 'ok', true);
  end;
  begin
    update public.secure_transactions set status = 'payment_confirmed' where id = v_tx;
    v_results := v_results || jsonb_build_object('test', 'buyer cannot confirm payment', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'buyer cannot confirm payment', 'ok', true);
  end;
  begin
    insert into public.secure_transactions
      (product_id, buyer_id, seller_id, amount, currency)
    values (v_product, v_buyer, v_seller, 1, 'UZS');
    v_results := v_results || jsonb_build_object('test', 'buyer cannot create transaction', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'buyer cannot create transaction', 'ok', true);
  end;
  begin
    perform public.review_seller_verification(v_buyer, 'verified');
    v_results := v_results || jsonb_build_object('test', 'buyer cannot verify seller', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'buyer cannot verify seller', 'ok', true);
  end;
  select count(*) into v_count from public.seller_verifications
    where user_id = v_buyer and status = 'pending';
  v_results := v_results || jsonb_build_object('test', 'seller reads own verification status', 'ok', v_count = 1);
  begin
    update public.seller_verifications set status = 'verified' where user_id = v_buyer;
    v_results := v_results || jsonb_build_object('test', 'seller cannot self-verify', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'seller cannot self-verify', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_outsider, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_outsider::text, true);
  execute 'set local role authenticated';
  select count(*) into v_count from public.secure_transactions where id = v_tx;
  v_results := v_results || jsonb_build_object('test', 'outsider cannot read transaction', 'ok', v_count = 0);
  select count(*) into v_count from public.secure_transaction_events
    where transaction_id = v_tx;
  v_results := v_results || jsonb_build_object('test', 'outsider cannot read transaction events', 'ok', v_count = 0);
  select count(*) into v_count from public.seller_verifications where user_id = v_buyer;
  v_results := v_results || jsonb_build_object('test', 'outsider cannot read seller verification', 'ok', v_count = 0);

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_unverified, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_unverified::text, true);
  execute 'set local role authenticated';
  begin
    perform public.request_seller_verification();
    v_results := v_results || jsonb_build_object('test', 'unverified phone cannot request seller review', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'unverified phone cannot request seller review', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';
  begin
    perform public.review_seller_verification(v_buyer, 'verified');
    v_results := v_results || jsonb_build_object('test', 'admin reviews seller request', 'ok', true);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'admin reviews seller request', 'ok', false, 'detail', sqlerrm);
  end;
  select count(*) into v_count from public.audit_logs
    where entity = 'seller_verification' and entity_id = v_buyer::text
      and action = 'review';
  v_results := v_results || jsonb_build_object('test', 'seller review is audited', 'ok', v_count = 1);

  execute 'reset role';
  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 16 RLS tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
