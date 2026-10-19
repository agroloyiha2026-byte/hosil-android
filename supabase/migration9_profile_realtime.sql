-- 9-migratsiya: profilga qo'shimcha ma'lumot va bildirishnomalar uchun Realtime.
alter table public.profiles add column if not exists district text;
alter table public.profiles add column if not exists farm_name text;

-- Yangi bildirishnoma ilovaga darhol yetib borishi uchun (RLS saqlanadi: faqat egasi oladi)
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null;
end $$;
