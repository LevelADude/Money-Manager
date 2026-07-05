-- 0032: Kategorien, Budgets, Sparziele, Vorlagen und Kategorie-Regeln pro
-- Besitzer trennen.
--
-- Bisher waren diese fünf Tabellen bewusst gruppenweit (RLS `for all using
-- (true)`, seit 0018) — jeder Angemeldete sah und änderte die Planungsdaten
-- ALLER Nutzer. Das widerspricht dem Konten-Modell (Besitzer + Freigaben).
--
-- Neu: gleiche Logik wie Konten/Buchungen — sichtbar/änderbar für den Besitzer
-- und Personen mit Freigabe (`can_view_owner` / `can_manage_owner`).
-- Preset-Kategorien (`is_preset = true`) bleiben für ALLE lesbar (gemeinsame
-- Standard-Kategorien); änderbar nur durch Admins.
--
-- Besitzer-Spalte:
--   * categories       -> neue Spalte owner_id (Presets: owner_id NULL = global)
--   * budgets/savings_goals/transaction_templates/category_rules -> vorhandene
--     Spalte created_by (Default auth.uid()) dient als Besitzer.
--
-- Die zusätzlichen RESTRICTIVE is_writer()-Policies (0016) bleiben bestehen und
-- greifen weiterhin (global „nur lesen"-Nutzer können weiterhin nicht schreiben).

-- 1) categories -----------------------------------------------------------
alter table public.categories
  add column if not exists owner_id uuid
    references public.profiles(id) on delete set null default auth.uid();

-- Presets ausdrücklich global halten (owner_id NULL), egal wer die Migration
-- ausführt.
update public.categories set owner_id = null where is_preset;

create index if not exists categories_owner_idx on public.categories(owner_id);

drop policy if exists categories_all    on public.categories;
drop policy if exists categories_select on public.categories;
drop policy if exists categories_insert on public.categories;
drop policy if exists categories_update on public.categories;
drop policy if exists categories_delete on public.categories;

create policy categories_select on public.categories for select
  using (is_preset or public.can_view_owner(owner_id));
create policy categories_insert on public.categories for insert
  with check (not is_preset and owner_id = auth.uid());
create policy categories_update on public.categories for update
  using ((is_preset and public.is_admin()) or public.can_manage_owner(owner_id))
  with check ((is_preset and public.is_admin()) or public.can_manage_owner(owner_id));
create policy categories_delete on public.categories for delete
  using ((is_preset and public.is_admin()) or public.can_manage_owner(owner_id));

-- 2) budgets --------------------------------------------------------------
drop policy if exists budgets_all    on public.budgets;
drop policy if exists budgets_select on public.budgets;
drop policy if exists budgets_insert on public.budgets;
drop policy if exists budgets_update on public.budgets;
drop policy if exists budgets_delete on public.budgets;

create policy budgets_select on public.budgets for select
  using (public.can_view_owner(created_by));
create policy budgets_insert on public.budgets for insert
  with check (created_by = auth.uid());
create policy budgets_update on public.budgets for update
  using (public.can_manage_owner(created_by))
  with check (public.can_manage_owner(created_by));
create policy budgets_delete on public.budgets for delete
  using (public.can_manage_owner(created_by));

-- 3) savings_goals --------------------------------------------------------
drop policy if exists savings_goals_all    on public.savings_goals;
drop policy if exists savings_goals_select on public.savings_goals;
drop policy if exists savings_goals_insert on public.savings_goals;
drop policy if exists savings_goals_update on public.savings_goals;
drop policy if exists savings_goals_delete on public.savings_goals;

create policy savings_goals_select on public.savings_goals for select
  using (public.can_view_owner(created_by));
create policy savings_goals_insert on public.savings_goals for insert
  with check (created_by = auth.uid());
create policy savings_goals_update on public.savings_goals for update
  using (public.can_manage_owner(created_by))
  with check (public.can_manage_owner(created_by));
create policy savings_goals_delete on public.savings_goals for delete
  using (public.can_manage_owner(created_by));

-- 4) transaction_templates ------------------------------------------------
drop policy if exists transaction_templates_all    on public.transaction_templates;
drop policy if exists transaction_templates_select on public.transaction_templates;
drop policy if exists transaction_templates_insert on public.transaction_templates;
drop policy if exists transaction_templates_update on public.transaction_templates;
drop policy if exists transaction_templates_delete on public.transaction_templates;

create policy transaction_templates_select on public.transaction_templates for select
  using (public.can_view_owner(created_by));
create policy transaction_templates_insert on public.transaction_templates for insert
  with check (created_by = auth.uid());
create policy transaction_templates_update on public.transaction_templates for update
  using (public.can_manage_owner(created_by))
  with check (public.can_manage_owner(created_by));
create policy transaction_templates_delete on public.transaction_templates for delete
  using (public.can_manage_owner(created_by));

-- 5) category_rules -------------------------------------------------------
drop policy if exists category_rules_all    on public.category_rules;
drop policy if exists category_rules_select on public.category_rules;
drop policy if exists category_rules_insert on public.category_rules;
drop policy if exists category_rules_update on public.category_rules;
drop policy if exists category_rules_delete on public.category_rules;

create policy category_rules_select on public.category_rules for select
  using (public.can_view_owner(created_by));
create policy category_rules_insert on public.category_rules for insert
  with check (created_by = auth.uid());
create policy category_rules_update on public.category_rules for update
  using (public.can_manage_owner(created_by))
  with check (public.can_manage_owner(created_by));
create policy category_rules_delete on public.category_rules for delete
  using (public.can_manage_owner(created_by));
