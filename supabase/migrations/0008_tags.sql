-- =====================================================================
-- Money-Manager · 0008_tags.sql · Tags je Buchung
-- =====================================================================
-- Frei vergebbare Schlagworte je Buchung als Text-Array (einfach, keine
-- Joins, gut filterbar). Beispiel: {'Urlaub','Geschäftlich'}.
-- =====================================================================

alter table public.transactions
  add column if not exists tags text[] not null default '{}';

-- GIN-Index für schnelles Filtern nach Tag (tags @> '{...}').
create index if not exists transactions_tags_idx
  on public.transactions using gin (tags);
