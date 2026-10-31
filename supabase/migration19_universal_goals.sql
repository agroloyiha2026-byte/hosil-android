-- Additive universal goals and task links. Existing financial_goals and tasks remain intact.
-- Apply manually after migration 18, after reviewing the target database and its policies.

create table if not exists public.user_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 160),
  description text,
  category text not null check (category in (
    'financial', 'farming', 'business', 'equipment', 'learning', 'personal', 'other'
  )),
  start_date date not null default current_date,
  due_date date,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  status text not null default 'planned' check (status in ('planned', 'active', 'completed', 'cancelled')),
  progress_mode text not null default 'tasks' check (progress_mode in ('metric', 'tasks', 'manual')),
  target_value numeric(18, 3) check (target_value is null or (target_value > 0 and target_value <> 'NaN'::numeric)),
  current_value numeric(18, 3) not null default 0 check (current_value >= 0 and current_value <> 'NaN'::numeric),
  manual_progress numeric(5, 2) not null default 0 check (manual_progress between 0 and 100),
  unit text,
  currency text check (currency is null or currency in ('UZS', 'USD')),
  crop_type text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (due_date is null or due_date >= start_date),
  check (progress_mode <> 'metric' or target_value is not null)
);

create index if not exists user_goals_owner_idx
  on public.user_goals (user_id, status, due_date, created_at desc);

create table if not exists public.goal_task_links (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.user_goals(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (goal_id, task_id)
);

create index if not exists goal_task_links_owner_goal_idx
  on public.goal_task_links (owner_id, goal_id);

create table if not exists public.user_goal_events (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.user_goals(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_goal_events_goal_idx
  on public.user_goal_events (goal_id, created_at desc);

create or replace function public.audit_user_goal_change()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  insert into public.user_goal_events (goal_id, user_id, event_type, details)
  values (
    new.id,
    new.user_id,
    case
      when tg_op = 'INSERT' then 'created'
      when new.status is distinct from old.status then 'status_changed'
      when new.current_value is distinct from old.current_value
        or new.manual_progress is distinct from old.manual_progress then 'progress_updated'
      else 'updated'
    end,
    jsonb_build_object(
      'status', new.status,
      'current_value', new.current_value,
      'manual_progress', new.manual_progress
    )
  );
  return new;
end $$;

drop trigger if exists user_goal_audit on public.user_goals;
create trigger user_goal_audit after insert or update on public.user_goals
  for each row execute function public.audit_user_goal_change();

create or replace function public.goal_task_link_before_write()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or new.owner_id <> auth.uid() then raise exception 'forbidden'; end if;
  if not exists (
    select 1 from public.user_goals g where g.id = new.goal_id and g.user_id = new.owner_id
  ) or not exists (
    select 1 from public.tasks t where t.id = new.task_id and t.user_id = new.owner_id
  ) then raise exception 'goal_task_owner_mismatch'; end if;
  return new;
end $$;

drop trigger if exists goal_task_link_before_write on public.goal_task_links;
create trigger goal_task_link_before_write before insert or update
  on public.goal_task_links for each row execute function public.goal_task_link_before_write();

create or replace function public.add_task_to_goal(
  p_goal_id uuid, p_title text, p_description text default null, p_due_at timestamptz default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_task_id uuid;
begin
  if auth.uid() is null or length(trim(coalesce(p_title, ''))) not between 1 and 160 then
    raise exception 'invalid_task';
  end if;
  if not exists (select 1 from public.user_goals where id = p_goal_id and user_id = auth.uid()) then
    raise exception 'forbidden';
  end if;
  insert into public.tasks (user_id, title, description, due_at, done, status)
  values (
    auth.uid(), trim(p_title), nullif(trim(coalesce(p_description, '')), ''),
    p_due_at, false, 'pending'
  ) returning id into v_task_id;
  insert into public.goal_task_links (goal_id, task_id, owner_id)
  values (p_goal_id, v_task_id, auth.uid());
  return v_task_id;
end $$;

alter table public.user_goals enable row level security;
alter table public.goal_task_links enable row level security;
alter table public.user_goal_events enable row level security;

revoke all on public.user_goals, public.goal_task_links, public.user_goal_events from anon, authenticated;
grant select, insert, update, delete on public.user_goals to authenticated;
grant select, insert, delete on public.goal_task_links to authenticated;
grant select on public.user_goal_events to authenticated;

drop policy if exists "user goals: owner access" on public.user_goals;
create policy "user goals: owner access" on public.user_goals for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "goal task links: owner access" on public.goal_task_links;
create policy "goal task links: owner access" on public.goal_task_links for all to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "goal events: owner read" on public.user_goal_events;
create policy "goal events: owner read" on public.user_goal_events for select to authenticated
  using (user_id = auth.uid());

revoke all on function public.add_task_to_goal(uuid, text, text, timestamptz) from public, anon;
grant execute on function public.add_task_to_goal(uuid, text, text, timestamptz) to authenticated;
