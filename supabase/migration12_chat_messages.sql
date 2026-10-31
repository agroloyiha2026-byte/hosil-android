-- Add private message threads to existing buyer/seller product inquiries.
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  inquiry_id uuid not null references public.inquiries(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) between 1 and 4000),
  read_by uuid references public.profiles(id) on delete set null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_inquiry_created_idx
  on public.chat_messages (inquiry_id, created_at);

alter table public.chat_messages enable row level security;
revoke all on public.chat_messages from anon, authenticated;
grant select, insert on public.chat_messages to authenticated;
grant update (read_by, read_at) on public.chat_messages to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'chat_messages'
      and policyname = 'chat messages: inquiry participants read'
  ) then
    create policy "chat messages: inquiry participants read"
      on public.chat_messages for select to authenticated
      using (
        exists (
          select 1
          from public.inquiries i
          join public.products p on p.id = i.product_id
          where i.id = chat_messages.inquiry_id
            and (i.buyer_id = auth.uid() or p.seller_id = auth.uid())
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'chat_messages'
      and policyname = 'chat messages: inquiry participants send'
  ) then
    create policy "chat messages: inquiry participants send"
      on public.chat_messages for insert to authenticated
      with check (
        sender_id = auth.uid()
        and read_by is null
        and read_at is null
        and exists (
          select 1
          from public.inquiries i
          join public.products p on p.id = i.product_id
          where i.id = chat_messages.inquiry_id
            and (i.buyer_id = auth.uid() or p.seller_id = auth.uid())
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'chat_messages'
      and policyname = 'chat messages: recipient marks read'
  ) then
    create policy "chat messages: recipient marks read"
      on public.chat_messages for update to authenticated
      using (
        sender_id <> auth.uid()
        and read_at is null
        and exists (
          select 1
          from public.inquiries i
          join public.products p on p.id = i.product_id
          where i.id = chat_messages.inquiry_id
            and (i.buyer_id = auth.uid() or p.seller_id = auth.uid())
        )
      )
      with check (
        read_by = auth.uid()
        and read_at is not null
        and sender_id <> auth.uid()
        and exists (
          select 1
          from public.inquiries i
          join public.products p on p.id = i.product_id
          where i.id = chat_messages.inquiry_id
            and (i.buyer_id = auth.uid() or p.seller_id = auth.uid())
        )
      );
  end if;
end $$;
