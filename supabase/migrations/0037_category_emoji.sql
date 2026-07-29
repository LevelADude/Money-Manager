-- 0037: Emoji(s) als alternatives Kategorie-Symbol.
--
-- Eine Kategorie hat entweder ein Material-Icon (Spalte `icon`, Token) ODER
-- 1–3 Emojis (Spalte `emoji`). Ist `emoji` gesetzt, ersetzt es das Icon in der
-- Anzeige. Gruppenweit wie die übrigen Kategorie-Felder.
alter table public.categories
  add column if not exists emoji text;
