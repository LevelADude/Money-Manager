-- =====================================================================
-- Money-Manager - setup.sql  (Komplett-Einrichtung der Datenbank)
-- =====================================================================
-- Einmalig fuer ein FRISCHES Supabase-Projekt: gesamten Inhalt im SQL-Editor einfuegen, Run.
-- Enthaelt die Migrationen 0001 bis 0020.
-- =====================================================================


-- ## Migration: 0001_init.sql

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


-- ## Migration: 0002_security_hardening.sql

-- =====================================================================
-- Money-Manager · 0002_security_hardening.sql
-- =====================================================================
-- Behebt Hinweise des Supabase-Security-Advisors:
--   1) Trigger-Hilfsfunktion bekommt einen festen (immutable) search_path.
--   2) Trigger-Funktionen sollen NICHT über den öffentlichen REST-RPC-
--      Endpunkt aufrufbar sein. (Trigger feuern unabhängig von EXECUTE-Rechten,
--      daher bleibt das Verhalten der App unverändert.)
--
-- Hinweis: Die Policies `*_all` mit `using (true)` sind ABSICHTLICH so – das
-- ist das gewünschte Modell "vertrauenswürdige Gruppe, alle dürfen alles".
-- =====================================================================

alter function public.set_updated_at() set search_path = '';

revoke execute on function public.set_updated_at()  from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;


-- ## Migration: 0003_model_v2.sql

-- =====================================================================
-- Money-Manager · 0003_model_v2.sql · Datenmodell v2 (Personal-Finance)
-- =====================================================================
-- Wandelt das Grundgerüst in eine vollwertige Finanz-App:
--   * accounts (Konten mit Typ, Anfangssaldo, Vermögens-Flag) ersetzt ledgers
--   * transactions mit Typ expense/income/transfer + Cent-Beträgen + Titel
--   * categories sind nun GRUPPENWEIT (kein ledger_id) + Preset
--   * deleted_at-Tombstones überall -> Local-First-Delta-Sync möglich
-- Die DB war leer -> sauberer Neuaufbau. profiles + Hilfsfunktionen bleiben.
-- =====================================================================

-- 1) v1-Objekte entfernen ------------------------------------------------
drop view  if exists public.ledger_balances;
drop table if exists public.transactions cascade;
drop table if exists public.categories   cascade;
drop table if exists public.ledgers      cascade;

-- updated_at-Helfer sicherstellen (mit fixem search_path, vgl. 0002)
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke execute on function public.set_updated_at() from public, anon, authenticated;

-- 2) accounts ------------------------------------------------------------
create table public.accounts (
  id                    uuid primary key default gen_random_uuid(),
  owner_id              uuid references public.profiles(id) on delete set null default auth.uid(),
  name                  text not null,
  type                  text not null default 'bank'
                          check (type in ('bank','cash','credit_card','savings','loan','investment','wallet','other')),
  currency              text not null default 'EUR',
  opening_balance_cents bigint  not null default 0,
  icon                  text,
  color                 integer,
  credit_limit_cents    bigint,
  include_in_net_worth  boolean not null default true,
  archived              boolean not null default false,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);
create index accounts_owner_idx   on public.accounts(owner_id);
create index accounts_updated_idx on public.accounts(updated_at);

create trigger accounts_set_updated_at before update on public.accounts
  for each row execute function public.set_updated_at();

-- 3) categories (gruppenweit) -------------------------------------------
create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  kind       text not null check (kind in ('income','expense')),
  parent_id  uuid references public.categories(id) on delete set null,
  icon       text,
  color      integer,
  is_preset  boolean not null default false,
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index categories_kind_idx    on public.categories(kind);
create index categories_updated_idx on public.categories(updated_at);

create trigger categories_set_updated_at before update on public.categories
  for each row execute function public.set_updated_at();

-- 4) transactions --------------------------------------------------------
create table public.transactions (
  id                  uuid primary key default gen_random_uuid(),
  account_id          uuid not null references public.accounts(id) on delete cascade,
  type                text not null check (type in ('expense','income','transfer')),
  amount_cents        bigint not null check (amount_cents >= 0),
  occurred_on         date not null default current_date,
  category_id         uuid references public.categories(id) on delete set null,
  transfer_account_id uuid references public.accounts(id) on delete cascade,
  title               text not null default '',
  note                text not null default '',
  created_by          uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  -- Übertrag braucht ein Zielkonto; andere Typen nicht
  constraint transfer_needs_target check (
    (type =  'transfer' and transfer_account_id is not null and transfer_account_id <> account_id)
    or
    (type <> 'transfer' and transfer_account_id is null)
  )
);
create index transactions_account_idx  on public.transactions(account_id);
create index transactions_occurred_idx on public.transactions(occurred_on);
create index transactions_updated_idx  on public.transactions(updated_at);
create index transactions_transfer_idx on public.transactions(transfer_account_id);

create trigger transactions_set_updated_at before update on public.transactions
  for each row execute function public.set_updated_at();

-- 5) View: Kontosaldo (Anfangssaldo + Buchungen, Überträge berücksichtigt)
create view public.account_balances
with (security_invoker = true) as
select
  a.id       as account_id,
  a.owner_id,
  a.name,
  a.type,
  a.currency,
  a.include_in_net_worth,
  a.archived,
  a.opening_balance_cents
    + coalesce((select sum(t.amount_cents) from public.transactions t
                where t.account_id = a.id and t.type = 'income'  and t.deleted_at is null), 0)
    - coalesce((select sum(t.amount_cents) from public.transactions t
                where t.account_id = a.id and t.type = 'expense' and t.deleted_at is null), 0)
    - coalesce((select sum(t.amount_cents) from public.transactions t
                where t.account_id = a.id and t.type = 'transfer' and t.deleted_at is null), 0)
    + coalesce((select sum(t.amount_cents) from public.transactions t
                where t.transfer_account_id = a.id and t.type = 'transfer' and t.deleted_at is null), 0)
    as balance_cents
from public.accounts a
where a.deleted_at is null;

-- 6) Row Level Security (Gruppe: authentifiziert = Vollzugriff) ----------
alter table public.accounts     enable row level security;
alter table public.categories   enable row level security;
alter table public.transactions enable row level security;

create policy accounts_all     on public.accounts     for all to authenticated using (true) with check (true);
create policy categories_all   on public.categories   for all to authenticated using (true) with check (true);
create policy transactions_all on public.transactions for all to authenticated using (true) with check (true);

-- 7) Realtime ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.accounts;     exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.categories;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.transactions; exception when duplicate_object then null; end;
end $$;

-- 8) Preset-Kategorien (gruppenweit, idempotent) -------------------------
do $$
begin
  if not exists (select 1 from public.categories where is_preset) then
    insert into public.categories (name, kind, is_preset, icon) values
      -- Ausgaben
      ('Lebensmittel','expense',true,'cart'),
      ('Restaurant & Café','expense',true,'restaurant'),
      ('Haushalt','expense',true,'home_supplies'),
      ('Wohnen & Miete','expense',true,'home'),
      ('Nebenkosten (Strom/Gas/Wasser)','expense',true,'bolt'),
      ('Internet & Telefon','expense',true,'wifi'),
      ('Auto & Tanken','expense',true,'car'),
      ('ÖPNV & Transport','expense',true,'bus'),
      ('Versicherungen','expense',true,'shield'),
      ('Gesundheit & Apotheke','expense',true,'health'),
      ('Kleidung','expense',true,'shirt'),
      ('Freizeit & Hobby','expense',true,'sports'),
      ('Abos & Streaming','expense',true,'subscription'),
      ('Reisen & Urlaub','expense',true,'flight'),
      ('Geschenke','expense',true,'gift'),
      ('Bildung','expense',true,'school'),
      ('Haustier','expense',true,'pet'),
      ('Kinder','expense',true,'child'),
      ('Spenden','expense',true,'donate'),
      ('Steuern & Gebühren','expense',true,'tax'),
      ('Sparen & Investieren','expense',true,'savings'),
      ('Sonstiges','expense',true,'more'),
      -- Einnahmen
      ('Gehalt & Lohn','income',true,'salary'),
      ('Bonus','income',true,'star'),
      ('Selbstständigkeit','income',true,'work'),
      ('Zinsen & Dividenden','income',true,'invest'),
      ('Erstattung','income',true,'refund'),
      ('Verkauf','income',true,'sale'),
      ('Geschenk erhalten','income',true,'gift'),
      ('Kindergeld','income',true,'child'),
      ('Sonstiges','income',true,'more');
  end if;
end $$;


-- ## Migration: 0004_budgets.sql

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


-- ## Migration: 0005_recurring.sql

-- =====================================================================
-- Money-Manager · 0005_recurring.sql · Wiederkehrende Buchungen
-- =====================================================================
-- Regeln für Daueraufträge (Miete, Gehalt, Abos …). Die App erzeugt fällige
-- Buchungen race-sicher (atomares "Beanspruchen" der Periode vor dem Anlegen).
-- =====================================================================

create table if not exists public.recurring_rules (
  id                  uuid    primary key default gen_random_uuid(),
  account_id          uuid    not null references public.accounts(id) on delete cascade,
  type                text    not null check (type in ('expense','income','transfer')),
  amount_cents        bigint  not null check (amount_cents >= 0),
  category_id         uuid    references public.categories(id) on delete set null,
  transfer_account_id uuid    references public.accounts(id) on delete cascade,
  title               text    not null default '',
  note                text    not null default '',
  interval_unit       text    not null check (interval_unit in ('day','week','month','year')),
  interval_count      int     not null default 1 check (interval_count >= 1),
  next_due            date    not null,
  end_date            date,
  active              boolean not null default true,
  created_by          uuid    references public.profiles(id) on delete set null default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint rec_transfer_needs_target check (
    (type =  'transfer' and transfer_account_id is not null and transfer_account_id <> account_id)
    or
    (type <> 'transfer' and transfer_account_id is null)
  )
);
create index if not exists recurring_next_due_idx on public.recurring_rules(next_due);
create index if not exists recurring_updated_idx  on public.recurring_rules(updated_at);

drop trigger if exists recurring_set_updated_at on public.recurring_rules;
create trigger recurring_set_updated_at before update on public.recurring_rules
  for each row execute function public.set_updated_at();

alter table public.recurring_rules enable row level security;
drop policy if exists recurring_all on public.recurring_rules;
create policy recurring_all on public.recurring_rules
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.recurring_rules; exception when duplicate_object then null; end;
end $$;


-- ## Migration: 0006_receipts.sql

-- =====================================================================
-- Money-Manager · 0006_receipts.sql · Belege/Fotos je Buchung
-- =====================================================================
-- Pfad zum Beleg (in Supabase Storage) an der Buchung + privater Bucket
-- "receipts" mit Zugriff für angemeldete Mitglieder.
-- =====================================================================

alter table public.transactions add column if not exists receipt_path text;

-- Privater Storage-Bucket für Belege
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Zugriff: jedes angemeldete Mitglied darf Belege lesen/hochladen/löschen.
drop policy if exists receipts_select on storage.objects;
create policy receipts_select on storage.objects
  for select to authenticated using (bucket_id = 'receipts');

drop policy if exists receipts_insert on storage.objects;
create policy receipts_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'receipts');

drop policy if exists receipts_update on storage.objects;
create policy receipts_update on storage.objects
  for update to authenticated using (bucket_id = 'receipts');

drop policy if exists receipts_delete on storage.objects;
create policy receipts_delete on storage.objects
  for delete to authenticated using (bucket_id = 'receipts');


-- ## Migration: 0007_admin_whitelist.sql

-- =====================================================================
-- Money-Manager · 0007_admin_whitelist.sql · Admin-Rechte + E-Mail-Whitelist
-- =====================================================================
-- - profiles.is_admin (1. Nutzer wird automatisch Admin)
-- - allowed_emails: nur freigeschaltete E-Mails dürfen sich registrieren
--   (serverseitig per Trigger erzwungen)
-- - is_admin()-Helfer + Admin-Policies
-- =====================================================================

alter table public.profiles add column if not exists is_admin boolean not null default false;

-- Helfer: Ist der aktuelle Nutzer Admin? (für RLS-Policies)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;
grant execute on function public.is_admin() to authenticated;

-- Whitelist-Tabelle
create table if not exists public.allowed_emails (
  email      text primary key,
  added_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.allowed_emails enable row level security;
drop policy if exists allowed_emails_admin on public.allowed_emails;
create policy allowed_emails_admin on public.allowed_emails
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Profil beim Signup anlegen; erster Nutzer wird Admin.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, is_admin)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    not exists (select 1 from public.profiles where is_admin = true)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Falls bereits Nutzer existieren, aber noch kein Admin: ältesten zum Admin machen.
update public.profiles set is_admin = true
where id = (select id from public.profiles order by created_at asc limit 1)
  and not exists (select 1 from public.profiles where is_admin = true);

-- Registrierungs-Sperre: nur Whitelist-E-Mails (erster Nutzer als Bootstrap erlaubt).
create or replace function public.enforce_email_whitelist()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from auth.users) = 0 then
    return new;
  end if;
  if exists (select 1 from public.allowed_emails where lower(email) = lower(new.email)) then
    return new;
  end if;
  raise exception 'E-Mail nicht freigeschaltet. Bitte den Administrator kontaktieren.';
end;
$$;
revoke execute on function public.enforce_email_whitelist() from public, anon, authenticated;

drop trigger if exists on_auth_user_whitelist on auth.users;
create trigger on_auth_user_whitelist
  before insert on auth.users
  for each row execute function public.enforce_email_whitelist();

-- Admins dürfen jedes Profil ändern (z. B. is_admin setzen).
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());


-- ## Migration: 0008_tags.sql

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


-- ## Migration: 0009_splits.sql

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


-- ## Migration: 0010_category_order.sql

-- =====================================================================
-- Money-Manager · 0010_category_order.sql · Sortierreihenfolge je Kategorie
-- =====================================================================
-- Erlaubt es, die Reihenfolge der Kategorien selbst festzulegen (Drag&Drop
-- in der Kategorie-Verwaltung). Niedrigere Werte zuerst.
-- =====================================================================

alter table public.categories
  add column if not exists sort_order integer not null default 0;


-- ## Migration: 0011_account_order.sql

-- =====================================================================
-- Money-Manager · 0011_account_order.sql · Sortierreihenfolge je Konto
-- =====================================================================
-- Erlaubt es, die Reihenfolge der Konten selbst festzulegen (Drag&Drop).
-- Innerhalb der Kontotyp-Gruppen wird danach sortiert.
-- =====================================================================

alter table public.accounts
  add column if not exists sort_order integer not null default 0;


-- ## Migration: 0012_templates.sql

-- =====================================================================
-- Money-Manager · 0012_templates.sql · Buchungs-Vorlagen (Favoriten)
-- =====================================================================
-- Wiederverwendbare Vorlagen für häufige Buchungen (z. B. „Wocheneinkauf").
-- Gruppenweit geteilt. Keine Auswirkung auf Salden – nur zum Vorbefüllen.
-- =====================================================================

create table if not exists public.transaction_templates (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null,
  account_id   uuid        references public.accounts(id) on delete set null,
  type         text        not null default 'expense',
  amount_cents bigint      not null default 0,
  category_id  uuid        references public.categories(id) on delete set null,
  title        text        not null default '',
  note         text        not null default '',
  tags         text[]      not null default '{}',
  created_by   uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now()
);

alter table public.transaction_templates enable row level security;
drop policy if exists transaction_templates_all on public.transaction_templates;
create policy transaction_templates_all on public.transaction_templates
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.transaction_templates;
  exception when duplicate_object then null; end;
end $$;


-- ## Migration: 0013_savings_goals.sql

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


-- ## Migration: 0014_audit_log.sql

-- =====================================================================
-- Money-Manager · 0014_audit_log.sql · Änderungsverlauf (Audit-Log)
-- =====================================================================
-- Protokolliert Anlegen/Ändern/Löschen/Wiederherstellen von Buchungen
-- (wer/wann/was) per Trigger. Speist Buchungs-Verlauf + Aktivitäts-Feed.
-- =====================================================================

create table if not exists public.audit_log (
  id         bigint generated always as identity primary key,
  table_name text        not null,
  row_id     uuid,
  action     text        not null,
  actor      uuid,
  data       jsonb,
  at         timestamptz not null default now()
);
create index if not exists audit_log_row_idx on public.audit_log(row_id);
create index if not exists audit_log_at_idx on public.audit_log(at desc);

alter table public.audit_log enable row level security;
drop policy if exists audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log
  for select to authenticated using (true);

-- Schreiben nur über den Trigger (SECURITY DEFINER), nicht direkt durch Nutzer.
create or replace function public.log_transaction_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_action text;
  v_row    jsonb;
  v_id     uuid;
begin
  if (tg_op = 'INSERT') then
    v_action := 'insert'; v_row := to_jsonb(new); v_id := new.id;
  elsif (tg_op = 'UPDATE') then
    if old.deleted_at is null and new.deleted_at is not null then
      v_action := 'delete';
    elsif old.deleted_at is not null and new.deleted_at is null then
      v_action := 'restore';
    else
      v_action := 'update';
    end if;
    v_row := to_jsonb(new); v_id := new.id;
  else
    v_action := 'purge'; v_row := to_jsonb(old); v_id := old.id;
  end if;
  insert into public.audit_log(table_name, row_id, action, actor, data)
    values ('transactions', v_id, v_action, auth.uid(), v_row);
  return null;
end;
$$;

drop trigger if exists trg_audit_transactions on public.transactions;
create trigger trg_audit_transactions
  after insert or update or delete on public.transactions
  for each row execute function public.log_transaction_change();

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.audit_log;
  exception when duplicate_object then null; end;
end $$;


-- ## Migration: 0015_comments.sql

-- =====================================================================
-- Money-Manager · 0015_comments.sql · Kommentare an Buchungen
-- =====================================================================
-- Kommentar-Thread je Buchung (Rückfragen klären). Gruppenweit geteilt.
-- =====================================================================

create table if not exists public.transaction_comments (
  id             uuid        primary key default gen_random_uuid(),
  transaction_id uuid        not null references public.transactions(id) on delete cascade,
  author         uuid        references public.profiles(id) on delete set null default auth.uid(),
  body           text        not null,
  created_at     timestamptz not null default now()
);
create index if not exists transaction_comments_tx_idx
  on public.transaction_comments(transaction_id);

alter table public.transaction_comments enable row level security;
drop policy if exists transaction_comments_all on public.transaction_comments;
create policy transaction_comments_all on public.transaction_comments
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.transaction_comments;
  exception when duplicate_object then null; end;
end $$;


-- ## Migration: 0016_roles.sql

-- =====================================================================
-- Money-Manager · 0016_roles.sql · Nur-Lesen-Rolle
-- =====================================================================
-- Mitglieder können auf "nur lesen" gesetzt werden (read_only). Solche
-- Nutzer dürfen weiterhin alles sehen, aber keine Daten mehr schreiben.
-- Durchgesetzt per RESTRICTIVE-Policies (zusätzlich zu den bestehenden).
-- =====================================================================

alter table public.profiles
  add column if not exists read_only boolean not null default false;

-- true, wenn der aktuelle Nutzer schreiben darf (nicht read_only).
create or replace function public.is_writer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not coalesce(
    (select read_only from public.profiles where id = auth.uid()), false);
$$;

-- Schreibrechte für read_only-Nutzer auf den Datentabellen sperren.
do $$
declare
  t text;
  tbls text[] := array[
    'transactions','accounts','categories','budgets','recurring_rules',
    'transaction_splits','savings_goals','transaction_templates',
    'transaction_comments'
  ];
begin
  foreach t in array tbls loop
    execute format('drop policy if exists %I on public.%I', t||'_ro_ins', t);
    execute format('create policy %I on public.%I as restrictive for insert to authenticated with check (public.is_writer())', t||'_ro_ins', t);
    execute format('drop policy if exists %I on public.%I', t||'_ro_upd', t);
    execute format('create policy %I on public.%I as restrictive for update to authenticated using (public.is_writer()) with check (public.is_writer())', t||'_ro_upd', t);
    execute format('drop policy if exists %I on public.%I', t||'_ro_del', t);
    execute format('create policy %I on public.%I as restrictive for delete to authenticated using (public.is_writer())', t||'_ro_del', t);
  end loop;
end $$;


-- ## Migration: 0017_category_rules.sql

-- =====================================================================
-- Money-Manager · 0017_category_rules.sql · Auto-Kategorisierungs-Regeln
-- =====================================================================
-- Regeln "Titel enthält <Stichwort> -> Kategorie". Gruppenweit geteilt.
-- Werden beim Erfassen automatisch angewandt.
-- =====================================================================

create table if not exists public.category_rules (
  id          uuid        primary key default gen_random_uuid(),
  keyword     text        not null,
  category_id uuid        not null references public.categories(id) on delete cascade,
  created_by  uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now()
);

alter table public.category_rules enable row level security;
drop policy if exists category_rules_all on public.category_rules;
create policy category_rules_all on public.category_rules
  for all to authenticated using (true) with check (true);

-- read_only-Schreibsperre konsistent mitnehmen (falls is_writer existiert).
do $$
begin
  if exists (select 1 from pg_proc where proname = 'is_writer') then
    execute 'drop policy if exists category_rules_ro_ins on public.category_rules';
    execute 'create policy category_rules_ro_ins on public.category_rules as restrictive for insert to authenticated with check (public.is_writer())';
    execute 'drop policy if exists category_rules_ro_upd on public.category_rules';
    execute 'create policy category_rules_ro_upd on public.category_rules as restrictive for update to authenticated using (public.is_writer()) with check (public.is_writer())';
    execute 'drop policy if exists category_rules_ro_del on public.category_rules';
    execute 'create policy category_rules_ro_del on public.category_rules as restrictive for delete to authenticated using (public.is_writer())';
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.category_rules;
  exception when duplicate_object then null; end;
end $$;


-- ## Migration: 0018_access_grants.sql

-- 0018: Pro-Person-Zugriff (Freigaben) statt "alle sehen alles".
-- Konten + Buchungen (inkl. Splits, Kommentare, Daueraufträge, Audit) sind nur
-- für den Besitzer und Personen mit Freigabe sichtbar/änderbar.
-- Kategorien, Budgets, Sparziele bleiben vorerst gruppenweit (gemeinsame Planung).

-- 1) Freigaben-Tabelle: owner gibt grantee Zugriff (view = ansehen, manage = verwalten)
create table if not exists public.access_grants (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  grantee_id uuid not null references auth.users(id) on delete cascade,
  level text not null default 'view' check (level in ('view', 'manage')),
  created_at timestamptz not null default now(),
  unique (owner_id, grantee_id),
  check (owner_id <> grantee_id)
);
alter table public.access_grants enable row level security;

-- 2) Hilfsfunktionen. SECURITY DEFINER -> umgehen RLS (kein Rekursionsproblem),
--    STABLE -> dürfen in Policies effizient genutzt werden.
create or replace function public.can_view_owner(owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select owner = auth.uid()
      or exists (select 1 from public.access_grants g
                 where g.owner_id = owner and g.grantee_id = auth.uid());
$$;

create or replace function public.can_manage_owner(owner uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select owner = auth.uid()
      or exists (select 1 from public.access_grants g
                 where g.owner_id = owner and g.grantee_id = auth.uid()
                   and g.level = 'manage');
$$;

create or replace function public.can_view_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_view_owner(a.owner_id));
$$;

create or replace function public.can_manage_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_manage_owner(a.owner_id));
$$;

create or replace function public.can_view_transaction(tx uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.transactions t
                 where t.id = tx and public.can_view_account(t.account_id));
$$;

create or replace function public.can_manage_transaction(tx uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.transactions t
                 where t.id = tx and public.can_manage_account(t.account_id));
$$;

-- 3) access_grants policies: jeder sieht Freigaben, an denen er beteiligt ist;
--    nur der Besitzer legt fest, wer auf SEINE Daten zugreift.
drop policy if exists ag_select on public.access_grants;
drop policy if exists ag_modify on public.access_grants;
create policy ag_select on public.access_grants for select
  using (owner_id = auth.uid() or grantee_id = auth.uid());
create policy ag_modify on public.access_grants for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- 4) accounts: Sichtbarkeit/Schreibrecht nach Besitz + Freigabe.
--    (Die bestehenden RESTRICTIVE is_writer()-Policies bleiben und greifen
--     zusätzlich, damit global "nur lesen"-Nutzer weiterhin nicht schreiben.)
drop policy if exists accounts_all on public.accounts;
create policy accounts_select on public.accounts for select
  using (public.can_view_owner(owner_id));
create policy accounts_insert on public.accounts for insert
  with check (owner_id = auth.uid());
create policy accounts_update on public.accounts for update
  using (public.can_manage_owner(owner_id))
  with check (public.can_manage_owner(owner_id));
create policy accounts_delete on public.accounts for delete
  using (public.can_manage_owner(owner_id));

-- 5) transactions: nach Konto-Besitzer.
drop policy if exists transactions_all on public.transactions;
create policy transactions_select on public.transactions for select
  using (public.can_view_account(account_id));
create policy transactions_insert on public.transactions for insert
  with check (public.can_manage_account(account_id));
create policy transactions_update on public.transactions for update
  using (public.can_manage_account(account_id))
  with check (public.can_manage_account(account_id));
create policy transactions_delete on public.transactions for delete
  using (public.can_manage_account(account_id));

-- 6) transaction_splits: nach zugehöriger Buchung.
drop policy if exists transaction_splits_all on public.transaction_splits;
create policy transaction_splits_select on public.transaction_splits for select
  using (public.can_view_transaction(transaction_id));
create policy transaction_splits_insert on public.transaction_splits for insert
  with check (public.can_manage_transaction(transaction_id));
create policy transaction_splits_update on public.transaction_splits for update
  using (public.can_manage_transaction(transaction_id))
  with check (public.can_manage_transaction(transaction_id));
create policy transaction_splits_delete on public.transaction_splits for delete
  using (public.can_manage_transaction(transaction_id));

-- 7) transaction_comments: nach zugehöriger Buchung.
drop policy if exists transaction_comments_all on public.transaction_comments;
create policy transaction_comments_select on public.transaction_comments for select
  using (public.can_view_transaction(transaction_id));
create policy transaction_comments_insert on public.transaction_comments for insert
  with check (public.can_manage_transaction(transaction_id));
create policy transaction_comments_update on public.transaction_comments for update
  using (public.can_manage_transaction(transaction_id))
  with check (public.can_manage_transaction(transaction_id));
create policy transaction_comments_delete on public.transaction_comments for delete
  using (public.can_manage_transaction(transaction_id));

-- 8) recurring_rules: nach Konto-Besitzer.
drop policy if exists recurring_all on public.recurring_rules;
create policy recurring_select on public.recurring_rules for select
  using (public.can_view_account(account_id));
create policy recurring_insert on public.recurring_rules for insert
  with check (public.can_manage_account(account_id));
create policy recurring_update on public.recurring_rules for update
  using (public.can_manage_account(account_id))
  with check (public.can_manage_account(account_id));
create policy recurring_delete on public.recurring_rules for delete
  using (public.can_manage_account(account_id));

-- 9) audit_log: nur Einträge zu sichtbaren Buchungen anzeigen.
drop policy if exists audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log for select
  using (public.can_view_transaction(row_id));


-- ## Migration: 0019_account_members.sql

-- 0019: Geteilte Konten (Gemeinschaftskonto).
-- Ein Konto gehört weiterhin einem Besitzer (owner_id), kann aber Mitglieder
-- haben. Mitglieder dürfen das Konto SEHEN und darauf BUCHEN (wie ein echtes
-- Gemeinschaftskonto). Das Konto selbst (umbenennen/löschen) bleibt dem
-- Besitzer (bzw. seinen manage-Freigaben) vorbehalten.

create table if not exists public.account_members (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (account_id, user_id)
);
alter table public.account_members enable row level security;

-- Ist der aktuelle Nutzer Besitzer des Kontos? (definer -> umgeht RLS)
create or replace function public.is_account_owner(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and a.owner_id = auth.uid());
$$;

-- Sicht/Verwaltung eines Kontos: Besitzer/Freigabe ODER Mitglied.
create or replace function public.can_view_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_view_owner(a.owner_id))
      or exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

create or replace function public.can_manage_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_manage_owner(a.owner_id))
      or exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

-- accounts: Mitglieder dürfen das geteilte Konto sehen (Bearbeiten/Löschen des
-- Kontos selbst bleibt bei Besitzer + manage-Freigaben).
drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select
  using (public.can_view_account(id));

-- account_members: Besitzer sieht/verwaltet die Mitgliederliste; jede:r sieht
-- die eigene Mitgliedschaft.
drop policy if exists am_select on public.account_members;
drop policy if exists am_modify on public.account_members;
create policy am_select on public.account_members for select
  using (public.is_account_owner(account_id) or user_id = auth.uid());
create policy am_modify on public.account_members for all
  using (public.is_account_owner(account_id))
  with check (public.is_account_owner(account_id));


-- ## Migration: 0020_fix_accounts_select_insert.sql

-- 0020: Fix - „Konto anlegen" schlug mit RLS-Fehler (42501) fehl.
--
-- Ursache: In 0019 wurde accounts_select auf can_view_account(id) umgestellt.
-- Diese Funktion fragt die accounts-Tabelle SELBST ab. Bei INSERT ... RETURNING
-- (die App holt die neue id zurück) ist die gerade eingefügte Zeile für diese
-- Unterabfrage noch nicht sichtbar -> die SELECT-Policy schlägt fehl -> 42501.
--
-- Fix: accounts_select prüft direkt die Spalten der Zeile (owner_id) + Freigabe
-- + Mitgliedschaft, OHNE accounts erneut abzufragen. is_account_member() kapselt
-- die Mitgliedschaftsprüfung (eigene Tabelle, kein Self-Query auf accounts).

create or replace function public.is_account_member(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select
  using (public.can_view_owner(owner_id) or public.is_account_member(id));

