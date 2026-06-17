-- =====================================================================
-- Money-Manager - setup.sql  (Komplett-Einrichtung der Datenbank)
-- =====================================================================
-- So benutzt du diese Datei (einmalig, fuer ein FRISCHES Supabase-Projekt):
--   1. Supabase-Dashboard oeffnen -> dein Projekt -> "SQL Editor".
--   2. Den GESAMTEN Inhalt dieser Datei hineinkopieren und auf "Run" klicken.
--   3. Fertig - alle Tabellen, Sicherheitsregeln, der Beleg-Speicher und die
--      Admin-Logik (erste registrierte Person = Admin) werden angelegt.
--
-- Enthaelt die Migrationen 0001-0007 in der richtigen Reihenfolge.
-- =====================================================================


-- ###################################################################
-- ## Migration: 0001_init.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0001_init.sql Â· Initiales Schema
-- =====================================================================
-- Modell: Kleine, vertrauenswÃ¼rdige Nutzergruppe.
--   * Jede Person fÃ¼hrt ihre BÃ¼cher (ledgers) GETRENNT (per owner_id).
--   * ABER: jedes authentifizierte Mitglied darf ALLE BÃ¼cher und Buchungen
--     LESEN und BEARBEITEN.
--   * Die "Trennung" ist organisatorisch (pro ledger/owner), keine
--     ZugriffsbeschrÃ¤nkung. Wer was angelegt hat, wird Ã¼ber owner_id /
--     created_by festgehalten (Attribution).
--
-- MÃ¶chtest du spÃ¤ter strengere PrivatsphÃ¤re (jede:r sieht nur eigene
-- BÃ¼cher + explizit geteilte), musst du nur die RLS-Policies unten Ã¤ndern
-- â€” die App-Struktur bleibt gleich.
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
-- ledgers  (die getrennten BÃ¼cher je Person)
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
-- Alle Mitglieder dÃ¼rfen alle Profile lesen (um Namen anzuzeigen).
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

-- Jede:r darf nur das EIGENE Profil Ã¤ndern / (nach-)anlegen.
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
-- Realtime: Tabellen fÃ¼r Live-Sync auf allen GerÃ¤ten freigeben
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


-- ###################################################################
-- ## Migration: 0002_security_hardening.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0002_security_hardening.sql
-- =====================================================================
-- Behebt Hinweise des Supabase-Security-Advisors:
--   1) Trigger-Hilfsfunktion bekommt einen festen (immutable) search_path.
--   2) Trigger-Funktionen sollen NICHT Ã¼ber den Ã¶ffentlichen REST-RPC-
--      Endpunkt aufrufbar sein. (Trigger feuern unabhÃ¤ngig von EXECUTE-Rechten,
--      daher bleibt das Verhalten der App unverÃ¤ndert.)
--
-- Hinweis: Die Policies `*_all` mit `using (true)` sind ABSICHTLICH so â€“ das
-- ist das gewÃ¼nschte Modell "vertrauenswÃ¼rdige Gruppe, alle dÃ¼rfen alles".
-- =====================================================================

alter function public.set_updated_at() set search_path = '';

revoke execute on function public.set_updated_at()  from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;


-- ###################################################################
-- ## Migration: 0003_model_v2.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0003_model_v2.sql Â· Datenmodell v2 (Personal-Finance)
-- =====================================================================
-- Wandelt das GrundgerÃ¼st in eine vollwertige Finanz-App:
--   * accounts (Konten mit Typ, Anfangssaldo, VermÃ¶gens-Flag) ersetzt ledgers
--   * transactions mit Typ expense/income/transfer + Cent-BetrÃ¤gen + Titel
--   * categories sind nun GRUPPENWEIT (kein ledger_id) + Preset
--   * deleted_at-Tombstones Ã¼berall -> Local-First-Delta-Sync mÃ¶glich
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
  -- Ãœbertrag braucht ein Zielkonto; andere Typen nicht
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

-- 5) View: Kontosaldo (Anfangssaldo + Buchungen, ÃœbertrÃ¤ge berÃ¼cksichtigt)
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
      ('Restaurant & CafÃ©','expense',true,'restaurant'),
      ('Haushalt','expense',true,'home_supplies'),
      ('Wohnen & Miete','expense',true,'home'),
      ('Nebenkosten (Strom/Gas/Wasser)','expense',true,'bolt'),
      ('Internet & Telefon','expense',true,'wifi'),
      ('Auto & Tanken','expense',true,'car'),
      ('Ã–PNV & Transport','expense',true,'bus'),
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
      ('Steuern & GebÃ¼hren','expense',true,'tax'),
      ('Sparen & Investieren','expense',true,'savings'),
      ('Sonstiges','expense',true,'more'),
      -- Einnahmen
      ('Gehalt & Lohn','income',true,'salary'),
      ('Bonus','income',true,'star'),
      ('SelbststÃ¤ndigkeit','income',true,'work'),
      ('Zinsen & Dividenden','income',true,'invest'),
      ('Erstattung','income',true,'refund'),
      ('Verkauf','income',true,'sale'),
      ('Geschenk erhalten','income',true,'gift'),
      ('Kindergeld','income',true,'child'),
      ('Sonstiges','income',true,'more');
  end if;
end $$;


-- ###################################################################
-- ## Migration: 0004_budgets.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0004_budgets.sql Â· Monatsbudgets je Kategorie
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


-- ###################################################################
-- ## Migration: 0005_recurring.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0005_recurring.sql Â· Wiederkehrende Buchungen
-- =====================================================================
-- Regeln fÃ¼r DauerauftrÃ¤ge (Miete, Gehalt, Abos â€¦). Die App erzeugt fÃ¤llige
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


-- ###################################################################
-- ## Migration: 0006_receipts.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0006_receipts.sql Â· Belege/Fotos je Buchung
-- =====================================================================
-- Pfad zum Beleg (in Supabase Storage) an der Buchung + privater Bucket
-- "receipts" mit Zugriff fÃ¼r angemeldete Mitglieder.
-- =====================================================================

alter table public.transactions add column if not exists receipt_path text;

-- Privater Storage-Bucket fÃ¼r Belege
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Zugriff: jedes angemeldete Mitglied darf Belege lesen/hochladen/lÃ¶schen.
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


-- ###################################################################
-- ## Migration: 0007_admin_whitelist.sql
-- ###################################################################

-- =====================================================================
-- Money-Manager Â· 0007_admin_whitelist.sql Â· Admin-Rechte + E-Mail-Whitelist
-- =====================================================================
-- - profiles.is_admin (1. Nutzer wird automatisch Admin)
-- - allowed_emails: nur freigeschaltete E-Mails dÃ¼rfen sich registrieren
--   (serverseitig per Trigger erzwungen)
-- - is_admin()-Helfer + Admin-Policies
-- =====================================================================

alter table public.profiles add column if not exists is_admin boolean not null default false;

-- Helfer: Ist der aktuelle Nutzer Admin? (fÃ¼r RLS-Policies)
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

-- Falls bereits Nutzer existieren, aber noch kein Admin: Ã¤ltesten zum Admin machen.
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

-- Admins dÃ¼rfen jedes Profil Ã¤ndern (z. B. is_admin setzen).
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

