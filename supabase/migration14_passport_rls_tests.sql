-- Run only in a disposable/test Supabase database after migration 14.
-- The final exception is intentional; the transaction rolls back test data.
do $$
declare
  v_seller uuid;
  v_buyer uuid;
  v_product uuid;
  v_passport uuid;
  v_public jsonb;
  v_count integer;
  v_results jsonb := '[]'::jsonb;
  v_summary text;
  v_failures integer;
begin
  select p.id, p.seller_id into v_product, v_seller
  from public.products p
  where p.status = 'active' and p.moderation_status = 'approved'
    and p.seller_id is not null
  limit 1;
  if v_product is null then
    raise exception 'Test needs an active, approved product';
  end if;
  select id into v_buyer from public.profiles where id <> v_seller limit 1;
  if v_buyer is null then raise exception 'Test needs a second profile'; end if;

  perform set_config('request.jwt.claims',
    json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_seller::text, true);
  execute 'set local role authenticated';
  v_passport := public.create_harvest_passport(v_product);
  v_results := v_results || jsonb_build_object('test', 'owner receives server-issued passport id', 'ok', v_passport is not null);

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_buyer, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_buyer::text, true);
  execute 'set local role authenticated';
  begin
    perform public.create_harvest_passport(v_product);
    v_results := v_results || jsonb_build_object('test', 'other user cannot issue passport', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'other user cannot issue passport', 'ok', true);
  end;
  begin
    perform public.revoke_harvest_passport(v_passport);
    v_results := v_results || jsonb_build_object('test', 'other user cannot revoke passport', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'other user cannot revoke passport', 'ok', true);
  end;
  begin
    insert into public.harvest_passports (product_id, owner_id)
    values (v_product, v_buyer);
    v_results := v_results || jsonb_build_object('test', 'client cannot insert passport row', 'ok', false);
  exception when others then
    v_results := v_results || jsonb_build_object('test', 'client cannot insert passport row', 'ok', true);
  end;

  execute 'reset role';
  perform set_config('request.jwt.claims', '{}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
  select public.verify_harvest_passport(v_passport) into v_public;
  v_results := v_results || jsonb_build_object(
    'test', 'public verification omits private and certification claims',
    'ok', v_public->>'status' = 'active'
      and v_public->>'quality_certified' = 'false'
      and not (v_public ? 'phone')
  );

  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_seller, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', v_seller::text, true);
  execute 'set local role authenticated';
  perform public.revoke_harvest_passport(v_passport);
  execute 'reset role';
  perform set_config('request.jwt.claims', '{}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
  select public.verify_harvest_passport(v_passport) into v_public;
  v_results := v_results || jsonb_build_object(
    'test', 'owner revocation is visible to public verifier',
    'ok', v_public->>'status' = 'revoked'
  );

  execute 'reset role';
  select count(*) into v_count from public.harvest_passports
    where id = v_passport and revoked_at is not null;
  v_results := v_results || jsonb_build_object('test', 'passport revocation persisted', 'ok', v_count = 1);

  select string_agg(
    case when (item->>'ok')::boolean then 'PASS ' else 'FAIL ' end || (item->>'test'),
    E'\n'
  ), count(*) filter (where not (item->>'ok')::boolean)
  into v_summary, v_failures
  from jsonb_array_elements(v_results) item;
  raise exception 'Migration 14 passport tests (failures: %); rollback expected.% %',
    v_failures, E'\n', v_summary;
end $$;
