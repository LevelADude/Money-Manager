-- 0035: Kategorie-unabhängiges Gesamtbudget + Perioden (Monat/Woche).
--
-- Bisher: genau ein Monatsbudget je Kategorie (category_id NOT NULL,
-- unique(category_id)). Neu: zusätzlich ein GESAMTbudget über alle Kategorien
-- hinweg (category_id NULL) mit wählbarer Periode Monat oder Woche.
--
-- Nebenbei: die alte GLOBALE Eindeutigkeit unique(category_id) passte seit der
-- Pro-Besitzer-Trennung (0032) nicht mehr — sie wird durch eine Eindeutigkeit
-- PRO BESITZER ersetzt (zwei Nutzer dürfen dieselbe Preset-Kategorie budgetieren).

alter table public.budgets alter column category_id drop not null;
alter table public.budgets add column if not exists period text not null default 'month';

alter table public.budgets drop constraint if exists budgets_category_unique;
alter table public.budgets drop constraint if exists budgets_period_chk;
alter table public.budgets
  add constraint budgets_period_chk check (period in ('week', 'month'));

-- Ein Kategorie-Budget je (Besitzer, Kategorie); ein Gesamtbudget je Besitzer.
-- Soft-gelöschte (deleted_at) blockieren nicht.
create unique index if not exists budgets_cat_owner_uq
  on public.budgets (created_by, category_id)
  where category_id is not null and deleted_at is null;
create unique index if not exists budgets_overall_owner_uq
  on public.budgets (created_by)
  where category_id is null and deleted_at is null;
