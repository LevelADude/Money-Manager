-- =====================================================================
-- Money-Manager · 0004_budgets.sql · Monatsbudgets je Kategorie
-- =====================================================================
-- Ein monatliches Budget je (Ausgabe-)Kategorie, gruppenweit geteilt.
-- =====================================================================

create table if not exists public.budgets (
  id           uuid        primary key default gen_random_uuid(),
  category_id  uuid        not null references public.categories(id) on delete cascade,
  amount_cents bigint      not null check (amount_cents >= 0),
  created_by   uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  constraint budgets_category_unique unique (category_id)
);
create index if not exists budgets_updated_idx on public.budgets(updated_at);

drop trigger if exists budgets_set_updated_at on public.budgets;
create trigger budgets_set_updated_at before update on public.budgets
  for each row execute function public.set_updated_at();

alter table public.budgets enable row level security;
drop policy if exists budgets_all on public.budgets;
create policy budgets_all on public.budgets
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.budgets; exception when duplicate_object then null; end;
end $$;
