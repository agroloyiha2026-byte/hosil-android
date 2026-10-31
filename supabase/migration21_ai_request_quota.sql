-- Daily AI quota. No client can read or mutate quota rows or call the quota RPC.
create table if not exists public.ai_request_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_day date not null default (timezone('utc', now()))::date,
  request_count integer not null default 0 check (request_count >= 0),
  primary key (user_id, usage_day)
);

alter table public.ai_request_usage enable row level security;
revoke all on public.ai_request_usage from anon, authenticated;

create or replace function public.consume_ai_request(p_user_id uuid, p_daily_limit integer)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  accepted integer;
begin
  if p_daily_limit < 1 or p_daily_limit > 500 then
    raise exception 'invalid daily limit';
  end if;

  insert into public.ai_request_usage (user_id, usage_day, request_count)
  values (p_user_id, (timezone('utc', now()))::date, 1)
  on conflict (user_id, usage_day) do update
    set request_count = public.ai_request_usage.request_count + 1
    where public.ai_request_usage.request_count < p_daily_limit
  returning request_count into accepted;

  return accepted is not null;
end;
$$;

revoke all on function public.consume_ai_request(uuid, integer) from public, anon, authenticated;
grant execute on function public.consume_ai_request(uuid, integer) to service_role;