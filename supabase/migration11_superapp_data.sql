-- Additive Hosil X modules: user savings goals and offline field journal.
-- Apply only after reviewing the project schema and RLS policies.

create table if not exists public.financial_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  target_amount numeric not null check (target_amount > 0),
  saved_amount numeric not null default 0 check (saved_amount >= 0),
  currency text not null default 'UZS' check (currency in ('UZS', 'USD')),
  due_date date,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists financial_goals_user_idx
  on public.financial_goals (user_id, created_at desc);
alter table public.financial_goals enable row level security;

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text,
  due_at timestamptz,
  done boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'completed', 'cancelled')),
  category text,
  priority text default 'medium' check (priority in ('low', 'medium', 'high')),
  goal_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists tasks_user_due_idx
  on public.tasks (user_id, due_at, created_at desc);
alter table public.tasks enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'tasks' and policyname = 'tasks: owner access') then
    create policy "tasks: owner access" on public.tasks
      for all to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'financial_goals' and policyname = 'financial goals: owner access') then
    create policy "financial goals: owner access" on public.financial_goals
      for all to authenticated
      using (user_id = auth.uid())
      with check (user_id = auth.uid());
  end if;
end $$;

create table if not exists public.fieldbook_entries (
  client_id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  crop_type text not null check (length(trim(crop_type)) > 0),
  activity_type text not null check (activity_type in ('planting', 'seeds', 'irrigation', 'fertilizer', 'pesticide', 'labor', 'fuel', 'harvest', 'income', 'note')),
  entry_date date not null,
  quantity numeric check (quantity is null or quantity >= 0),
  unit text,
  amount numeric check (amount is null or amount >= 0),
  currency text not null default 'UZS' check (currency in ('UZS', 'USD')),
  note text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists fieldbook_entries_user_date_idx
  on public.fieldbook_entries (user_id, entry_date desc);
alter table public.fieldbook_entries enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'fieldbook_entries' and policyname = 'fieldbook: owner reads') then
    create policy "fieldbook: owner reads" on public.fieldbook_entries
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

revoke insert, update, delete on public.fieldbook_entries from anon, authenticated;
grant select on public.fieldbook_entries to authenticated;

create or replace function public.sync_fieldbook_entry(
  p_client_id uuid,
  p_updated_at timestamptz,
  p_entry jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_entry public.fieldbook_entries;
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  if p_client_id is null or p_updated_at is null or p_entry is null then raise exception 'invalid_entry'; end if;
  if coalesce(p_entry->>'crop_type', '') = '' then raise exception 'crop_required'; end if;
  if coalesce(p_entry->>'activity_type', '') not in ('planting', 'seeds', 'irrigation', 'fertilizer', 'pesticide', 'labor', 'fuel', 'harvest', 'income', 'note') then
    raise exception 'invalid_activity';
  end if;

  insert into public.fieldbook_entries (
    client_id, user_id, crop_type, activity_type, entry_date, quantity, unit,
    amount, currency, note, deleted, updated_at
  ) values (
    p_client_id, auth.uid(), trim(p_entry->>'crop_type'), p_entry->>'activity_type',
    (p_entry->>'entry_date')::date, nullif(p_entry->>'quantity', '')::numeric,
    nullif(trim(p_entry->>'unit'), ''), nullif(p_entry->>'amount', '')::numeric,
    coalesce(nullif(p_entry->>'currency', ''), 'UZS'), nullif(trim(p_entry->>'note'), ''),
    coalesce((p_entry->>'deleted')::boolean, false), p_updated_at
  )
  on conflict (client_id) do update set
    crop_type = excluded.crop_type,
    activity_type = excluded.activity_type,
    entry_date = excluded.entry_date,
    quantity = excluded.quantity,
    unit = excluded.unit,
    amount = excluded.amount,
    currency = excluded.currency,
    note = excluded.note,
    deleted = excluded.deleted,
    updated_at = excluded.updated_at
  where public.fieldbook_entries.user_id = auth.uid()
    and public.fieldbook_entries.updated_at < excluded.updated_at
  returning * into v_entry;

  if not found then
    select * into v_entry from public.fieldbook_entries
      where client_id = p_client_id and user_id = auth.uid();
    if not found then raise exception 'forbidden'; end if;
  end if;

  return to_jsonb(v_entry);
end $$;

revoke all on function public.sync_fieldbook_entry(uuid, timestamptz, jsonb) from public, anon;
grant execute on function public.sync_fieldbook_entry(uuid, timestamptz, jsonb) to authenticated;
