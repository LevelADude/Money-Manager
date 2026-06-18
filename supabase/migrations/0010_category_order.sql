-- =====================================================================
-- Money-Manager · 0010_category_order.sql · Sortierreihenfolge je Kategorie
-- =====================================================================
-- Erlaubt es, die Reihenfolge der Kategorien selbst festzulegen (Drag&Drop
-- in der Kategorie-Verwaltung). Niedrigere Werte zuerst.
-- =====================================================================

alter table public.categories
  add column if not exists sort_order integer not null default 0;
