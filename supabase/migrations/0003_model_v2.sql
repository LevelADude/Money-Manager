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
