-- =====================================================================
-- Money-Manager · 0001_init.sql · Initiales Schema
-- =====================================================================
-- Modell: Kleine, vertrauenswürdige Nutzergruppe.
--   * Jede Person führt ihre Bücher (ledgers) GETRENNT (per owner_id).
--   * ABER: jedes authentifizierte Mitglied darf ALLE Bücher und Buchungen
--     LESEN und BEARBEITEN.
--   * Die "Trennung" ist organisatorisch (pro ledger/owner), keine
--     Zugriffsbeschränkung. Wer was angelegt hat, wird über owner_id /
--     created_by festgehalten (Attribution).
--
-- Möchtest du später strengere Privatsphäre (jede:r sieht nur eigene
-- Bücher + explizit geteilte), musst du nur die RLS-Policies unten ändern
-- — die App-Struktur bleibt gleich.
-- =====================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- ---------------------------------------------------------------------
-- Hilfsfunktion: updated_at automatisch setzen
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =====================================================================
-- profiles  (1:1 zu auth.users)
-- =====================================================================
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text        not null default '',
  created_at   timestamptz not null default now()
);
comment on table public.profiles is 'App-Profil, 1:1 zu auth.users.';

-- Beim Signup automatisch ein Profil anlegen
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- ledgers  (die getrennten Bücher je Person)
-- =====================================================================
create table if not exists public.ledgers (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  owner_id   uuid        references public.profiles(id) on delete set null default auth.uid(),
  currency   text        not null default 'EUR',
  archived   boolean     not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists ledgers_owner_id_idx on public.ledgers(owner_id);

drop trigger if exists ledgers_set_updated_at on public.ledgers;
create trigger ledgers_set_updated_at
  before update on public.ledgers
  for each row execute function public.set_updated_at();

-- =====================================================================
-- categories  (Einnahme-/Ausgabe-Kategorien je Buch)
-- =====================================================================
create table if not exists public.categories (
  id         uuid        primary key default gen_random_uuid(),
  ledger_id  uuid        not null references public.ledgers(id) on delete cascade,
  name       text        not null,
  kind       text        not null check (kind in ('income','expense')),
  created_at timestamptz not null default now()
);
create index if not exists categories_ledger_id_idx on public.categories(ledger_id);

-- =====================================================================
-- transactions  (die eigentlichen Buchungen)
-- =====================================================================
create table if not exists public.transactions (
  id          uuid          primary key default gen_random_uuid(),
  ledger_id   uuid          not null references public.ledgers(id) on delete cascade,
  category_id uuid          references public.categories(id) on delete set null,
  occurred_on date          not null default current_date,
  direction   text          not null check (direction in ('income','expense')),
  amount      numeric(14,2) not null check (amount >= 0),
  note        text          not null default '',
  created_by  uuid          references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz   not null default now(),
  updated_at  timestamptz   not null default now()
);
create index if not exists transactions_ledger_id_idx  on public.transactions(ledger_id);
create index if not exists transactions_occurred_on_idx on public.transactions(occurred_on);

drop trigger if exists transactions_set_updated_at on public.transactions;
create trigger transactions_set_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

-- =====================================================================
-- View: Kontostand je Buch (Einnahmen - Ausgaben)
-- =====================================================================
create or replace view public.ledger_balances
with (security_invoker = true) as
select
  l.id        as ledger_id,
  l.name,
  l.currency,
  l.owner_id,
  coalesce(sum(case when t.direction = 'income' then t.amount else -t.amount end), 0)::numeric(14,2) as balance,
  count(t.id) as transaction_count
from public.ledgers l
left join public.transactions t on t.ledger_id = l.id
group by l.id, l.name, l.currency, l.owner_id;

-- =====================================================================
-- Row Level Security
-- =====================================================================
alter table public.profiles     enable row level security;
alter table public.ledgers      enable row level security;
alter table public.categories   enable row level security;
alter table public.transactions enable row level security;

-- ---- profiles -------------------------------------------------------
-- Alle Mitglieder dürfen alle Profile lesen (um Namen anzuzeigen).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

-- Jede:r darf nur das EIGENE Profil ändern / (nach-)anlegen.
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---- ledgers / categories / transactions ----------------------------
-- Vertrauensgruppe: jedes authentifizierte Mitglied darf alles (CRUD).
drop policy if exists ledgers_all on public.ledgers;
create policy ledgers_all on public.ledgers
  for all to authenticated using (true) with check (true);

drop policy if exists categories_all on public.categories;
create policy categories_all on public.categories
  for all to authenticated using (true) with check (true);

drop policy if exists transactions_all on public.transactions;
create policy transactions_all on public.transactions
  for all to authenticated using (true) with check (true);

-- =====================================================================
-- Realtime: Tabellen für Live-Sync auf allen Geräten freigeben
-- =====================================================================
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.ledgers;      exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.categories;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.transactions; exception when duplicate_object then null; end;
end $$;
