-- 0039: RLS-Policies beschleunigen (Hinweise des Supabase-Performance-Advisors).
--
-- Reine Performance-Migration: WER WAS darf, bleibt exakt gleich.
--
-- 1) auth.uid() wurde in 16 Policies pro Zeile neu ausgewertet. Als
--    (select auth.uid()) rechnet Postgres den Wert einmal pro Abfrage.
-- 2) Auf einigen Tabellen galten für dieselbe Aktion zwei Policies (eine
--    "FOR ALL"-Policy deckte SELECT mit ab, zusätzlich zur SELECT-Policy).
--    Die "FOR ALL"-Policies werden in INSERT/UPDATE/DELETE aufgeteilt. Das
--    ändert nichts an den Rechten, weil die jeweilige SELECT-Policy schon
--    mindestens dasselbe erlaubt (Besitzer sieht seine Zeilen ohnehin).
-- 3) profiles: die zwei UPDATE-Policies (selbst / Admin) werden zu einer
--    zusammengefasst (gleiche Bedingung, mit OR verknüpft).
--
-- Idempotent: beliebig oft ausführbar.

-- ---------------------------------------------------------------------
-- 1) Nur der Ausdruck ändert sich (Policy bleibt bestehen).
-- ---------------------------------------------------------------------
alter policy profiles_insert_self on public.profiles
  with check (id = (select auth.uid()));

alter policy ag_select on public.access_grants
  using (owner_id = (select auth.uid()) or grantee_id = (select auth.uid()));

alter policy accounts_insert on public.accounts
  with check (owner_id = (select auth.uid()));

alter policy am_select on public.account_members
  using (public.is_account_owner(account_id) or user_id = (select auth.uid()));

alter policy categories_insert on public.categories
  with check ((not is_preset) and owner_id = (select auth.uid()));

alter policy budgets_insert on public.budgets
  with check (created_by = (select auth.uid()));

alter policy savings_goals_insert on public.savings_goals
  with check (created_by = (select auth.uid()));

alter policy transaction_templates_insert on public.transaction_templates
  with check (created_by = (select auth.uid()));

alter policy category_rules_insert on public.category_rules
  with check (created_by = (select auth.uid()));

alter policy account_groups_select on public.account_groups
  using (owner_id = (select auth.uid()));

alter policy category_prefs_select on public.category_prefs
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 2) "FOR ALL" -> INSERT / UPDATE / DELETE (SELECT regelt die *_select-Policy).
-- ---------------------------------------------------------------------

-- access_grants: nur der Besitzer verwaltet seine Freigaben.
drop policy if exists ag_modify on public.access_grants;
drop policy if exists ag_insert on public.access_grants;
drop policy if exists ag_update on public.access_grants;
drop policy if exists ag_delete on public.access_grants;
create policy ag_insert on public.access_grants for insert
  with check (owner_id = (select auth.uid()));
create policy ag_update on public.access_grants for update
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy ag_delete on public.access_grants for delete
  using (owner_id = (select auth.uid()));

-- account_groups
drop policy if exists account_groups_modify on public.account_groups;
drop policy if exists account_groups_insert on public.account_groups;
drop policy if exists account_groups_update on public.account_groups;
drop policy if exists account_groups_delete on public.account_groups;
create policy account_groups_insert on public.account_groups for insert
  with check (owner_id = (select auth.uid()));
create policy account_groups_update on public.account_groups for update
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy account_groups_delete on public.account_groups for delete
  using (owner_id = (select auth.uid()));

-- account_members: nur der Besitzer des Kontos verwaltet die Mitglieder.
drop policy if exists am_modify on public.account_members;
drop policy if exists am_insert on public.account_members;
drop policy if exists am_update on public.account_members;
drop policy if exists am_delete on public.account_members;
create policy am_insert on public.account_members for insert
  with check (public.is_account_owner(account_id));
create policy am_update on public.account_members for update
  using (public.is_account_owner(account_id))
  with check (public.is_account_owner(account_id));
create policy am_delete on public.account_members for delete
  using (public.is_account_owner(account_id));

-- category_prefs
drop policy if exists category_prefs_modify on public.category_prefs;
drop policy if exists category_prefs_insert on public.category_prefs;
drop policy if exists category_prefs_update on public.category_prefs;
drop policy if exists category_prefs_delete on public.category_prefs;
create policy category_prefs_insert on public.category_prefs for insert
  with check (owner_id = (select auth.uid()));
create policy category_prefs_update on public.category_prefs for update
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy category_prefs_delete on public.category_prefs for delete
  using (owner_id = (select auth.uid()));

-- currencies: lesen per can_view_owner (deckt den Besitzer ab), ändern nur
-- der Besitzer.
drop policy if exists currencies_modify on public.currencies;
drop policy if exists currencies_insert on public.currencies;
drop policy if exists currencies_update on public.currencies;
drop policy if exists currencies_delete on public.currencies;
create policy currencies_insert on public.currencies for insert
  with check (owner_id = (select auth.uid()));
create policy currencies_update on public.currencies for update
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy currencies_delete on public.currencies for delete
  using (owner_id = (select auth.uid()));

-- archived_years: alle Angemeldeten lesen (archived_years_select), nur Admins
-- schreiben.
drop policy if exists archived_years_admin_write on public.archived_years;
drop policy if exists archived_years_admin_insert on public.archived_years;
drop policy if exists archived_years_admin_update on public.archived_years;
drop policy if exists archived_years_admin_delete on public.archived_years;
create policy archived_years_admin_insert on public.archived_years
  for insert to authenticated
  with check (public.is_admin());
create policy archived_years_admin_update on public.archived_years
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());
create policy archived_years_admin_delete on public.archived_years
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------
-- 3) profiles: eine UPDATE-Policy statt zwei.
-- ---------------------------------------------------------------------
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists profiles_admin_update on public.profiles;
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) or public.is_admin())
  with check (id = (select auth.uid()) or public.is_admin());
