-- =====================================================================
-- Money-Manager · 0023_admin_maintenance.sql · Speicher-Statistik + Wartung
-- =====================================================================
-- 1) get_storage_stats(): aktuelle DB- und Datei-Speichergröße (für die
--    Fortschrittsbalken im Admin-Bereich). Für alle Angemeldeten lesbar.
-- 2) admin_wipe_data(): leert ALLE Finanzdaten, behält Nutzer/Whitelist.
-- 3) admin_factory_reset(): leert ALLES inkl. Profile/Whitelist (Werkszustand).
--
-- (2)+(3) truncaten Tabellen. Sie werden NUR vom service_role aufgerufen
-- (über die Edge Functions admin-wipe-data / admin-factory-reset, die zuvor
-- die Admin- bzw. Besitzer-Rolle des Aufrufers prüfen). Das Löschen der
-- auth.users beim Werks-Reset übernimmt die Edge Function per Admin-API.
-- =====================================================================

-- --- 1) Speicher-Statistik -------------------------------------------
create or replace function public.get_storage_stats()
returns table (db_bytes bigint, storage_bytes bigint)
language sql
stable
security definer
set search_path = public
as $$
  select
    pg_database_size(current_database())::bigint as db_bytes,
    coalesce(
      (select sum((metadata->>'size')::bigint) from storage.objects), 0
    )::bigint as storage_bytes;
$$;
revoke all on function public.get_storage_stats() from public;
grant execute on function public.get_storage_stats() to authenticated;

-- --- 2) Nur Daten leeren (Nutzer/Whitelist bleiben) ------------------
create or replace function public.admin_wipe_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.categories,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log
  cascade;
end;
$$;
revoke all on function public.admin_wipe_data() from public;
grant execute on function public.admin_wipe_data() to service_role;

-- --- 3) Werkszustand (alles weg, auch Profile + Whitelist) -----------
create or replace function public.admin_factory_reset()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.categories,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log,
    public.allowed_emails,
    public.profiles
  cascade;
end;
$$;
revoke all on function public.admin_factory_reset() from public;
grant execute on function public.admin_factory_reset() to service_role;
