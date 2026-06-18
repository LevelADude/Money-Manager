-- =====================================================================
-- Money-Manager · 0009_splits.sql · Split-Buchungen (Aufteilungen)
-- =====================================================================
-- Eine Buchung kann auf mehrere Kategorien aufgeteilt werden (z. B. ein
-- Einkauf: 30 € Lebensmittel + 10 € Drogerie). Die Summe der Aufteilungen
-- entspricht dem Buchungsbetrag. Wird gemeinsam (gruppenweit) geteilt.
-- =====================================================================

create table if not exists public.transaction_splits (
  id             uuid        primary key default gen_random_uuid(),
  transaction_id uuid        not null references public.transactions(id) on delete cascade,
  category_id    uuid        references public.categories(id) on delete set null,
  amount_cents   bigint      not null check (amount_cents >= 0),
  note           text        not null default '',
  created_at     timestamptz not null default now()
);

create index if not exists transaction_splits_tx_idx
  on public.transaction_splits(transaction_id);

alter table public.transaction_splits enable row level security;
drop policy if exists transaction_splits_all on public.transaction_splits;
create policy transaction_splits_all on public.transaction_splits
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.transaction_splits;
  exception when duplicate_object then null; end;
end $$;
