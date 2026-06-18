-- =====================================================================
-- Money-Manager · 0013_savings_goals.sql · Sparziele
-- =====================================================================
-- Sparziele mit Zielbetrag, optionalem Zieldatum und bisher gespartem Betrag.
-- Gruppenweit geteilt. Beiträge erhöhen/verringern saved_cents.
-- =====================================================================

create table if not exists public.savings_goals (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null,
  target_cents bigint      not null default 0 check (target_cents >= 0),
  saved_cents  bigint      not null default 0,
  target_date  date,
  created_by   uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now()
);

alter table public.savings_goals enable row level security;
drop policy if exists savings_goals_all on public.savings_goals;
create policy savings_goals_all on public.savings_goals
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.savings_goals;
  exception when duplicate_object then null; end;
end $$;
