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
