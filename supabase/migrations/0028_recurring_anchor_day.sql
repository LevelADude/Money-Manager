-- =====================================================================
-- Money-Manager · 0028_recurring_anchor_day.sql
-- =====================================================================
-- Fester Anker-Tag (Soll-Tag des Monats, 1–31) je Dauerauftrag. Ohne ihn ist
-- "Zahlung am 28." nicht von "Zahlung am Monatsende" unterscheidbar, sobald das
-- Datum durch den Februar läuft -> Monatsregeln driften. Mit dem Anker rechnet
-- die App das nächste Fälligkeitsdatum stabil vom Soll-Tag aus (s. advanceDate).
-- Backfill bestehender Regeln aus dem aktuellen next_due-Tag.
-- =====================================================================

alter table public.recurring_rules
  add column if not exists anchor_day smallint;

update public.recurring_rules
   set anchor_day = extract(day from next_due)::smallint
 where anchor_day is null;
