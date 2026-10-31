-- Private, user-bound FCM registrations. Tokens are never readable by clients.
create table if not exists public.device_tokens (
  token text primary key check (length(token) between 20 and 4096),
  user_id uuid not null references public.profiles(id) on delete cascade,
  platform text not null check (platform in ('android')),
  last_seen_at timestamptz not null default now(),
  disabled_at timestamptz
);

create index if not exists device_tokens_user_idx on public.device_tokens (user_id);
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;
grant all on public.device_tokens to service_role;

create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  if p_token is null or length(p_token) < 20 or length(p_token) > 4096 then raise exception 'invalid_token'; end if;
  if p_platform <> 'android' then raise exception 'unsupported_platform'; end if;

  insert into public.device_tokens(token, user_id, platform, last_seen_at, disabled_at)
  values (p_token, auth.uid(), p_platform, now(), null)
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    last_seen_at = now(),
    disabled_at = null;
end $$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  delete from public.device_tokens where token = p_token and user_id = auth.uid();
end $$;

create table if not exists public.push_deliveries (
  notification_id uuid primary key,
  status text not null check (status in ('processing', 'sent', 'failed')),
  attempts integer not null default 1 check (attempts > 0),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  last_error text
);
alter table public.push_deliveries enable row level security;
revoke all on public.push_deliveries from public, anon, authenticated;
grant all on public.push_deliveries to service_role;

create or replace function public.claim_push_delivery(p_notification_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $$
  with claimed as (
    insert into public.push_deliveries as existing (notification_id, status)
    values (p_notification_id, 'processing')
    on conflict (notification_id) do update set
      status = 'processing',
      attempts = existing.attempts + 1,
      started_at = now(),
      completed_at = null,
      last_error = null
    where existing.status = 'failed'
      or (existing.status = 'processing'
          and existing.started_at < now() - interval '10 minutes')
    returning notification_id
  )
  select exists(select 1 from claimed);
$$;

create or replace function public.complete_push_delivery(
  p_notification_id uuid,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_status not in ('sent', 'failed') then raise exception 'invalid_status'; end if;
  update public.push_deliveries
    set status = p_status, completed_at = now(),
        last_error = case when p_status = 'failed' then left(coalesce(p_error, 'delivery_failed'), 500) else null end
    where notification_id = p_notification_id and status = 'processing';
  if not found then raise exception 'delivery_not_claimed'; end if;
end $$;

revoke all on function public.register_device_token(text, text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
revoke all on function public.claim_push_delivery(uuid) from public, anon, authenticated;
revoke all on function public.complete_push_delivery(uuid, text, text) from public, anon, authenticated;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;
grant execute on function public.claim_push_delivery(uuid) to service_role;
grant execute on function public.complete_push_delivery(uuid, text, text) to service_role;
