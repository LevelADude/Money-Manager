-- =====================================================================
-- Money-Manager · 0011_account_order.sql · Sortierreihenfolge je Konto
-- =====================================================================
-- Erlaubt es, die Reihenfolge der Konten selbst festzulegen (Drag&Drop).
-- Innerhalb der Kontotyp-Gruppen wird danach sortiert.
-- =====================================================================

alter table public.accounts
  add column if not exists sort_order integer not null default 0;
