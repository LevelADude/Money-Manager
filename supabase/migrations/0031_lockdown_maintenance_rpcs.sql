-- 0031: Sicherheits-Hotfix — zerstörerische Wartungs-RPCs abriegeln.
--
-- Problem: admin_wipe_data(), admin_factory_reset() und cleanup_old_data()
-- waren auf der Prod-DB für die Rollen `anon` UND `authenticated` ausführbar
-- (per REST /rest/v1/rpc/...), OHNE interne Rechteprüfung. Der anon-Key ist
-- öffentlich (steckt in jedem Web-Bundle und in assets/db_connection/
-- connection.json im public Repo) -> jeder Fremde konnte die komplette DB
-- per einzelnem HTTP-POST leeren, ohne Login.
--
-- Ursache: `revoke all on function ... from public` (setup.sql) entfernt NUR
-- die PUBLIC-Grants. Supabase vergibt über ALTER DEFAULT PRIVILEGES beim
-- Anlegen zusätzlich EXECUTE direkt an `anon` und `authenticated` — die blieben
-- bestehen.
--
-- Fix:
--   (1) EXECUTE explizit von anon + authenticated (+ public) entziehen; nur
--       service_role behält Zugriff. Edge Functions (admin-wipe-data,
--       admin-factory-reset) rufen über service_role auf und prüfen den
--       Aufrufer selbst -> laufen weiter. cleanup_old_data läuft per pg_cron
--       (Owner-/postgres-Rolle) -> läuft weiter.
--   (2) Defense-in-depth: interner Guard in den zerstörerischen Funktionen,
--       der einen EINGELOGGTEN Nicht-Admin abweist. service_role/cron haben
--       auth.uid() = NULL und bleiben erlaubt (der Aufrufer wird dort bereits
--       serverseitig geprüft). Schützt zusätzlich, falls jemals wieder ein
--       Grant an `authenticated` durchrutscht.

-- (2) Interne Guards nachrüsten (Funktionskörper sonst unverändert).
create or replace function public.admin_wipe_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Keine Admin-Rechte';
  end if;

  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log
  cascade;

  delete from public.categories where is_preset = false;
  perform public._seed_preset_categories();
end;
$$;

create or replace function public.admin_factory_reset()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Keine Admin-Rechte';
  end if;

  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log,
    public.allowed_emails,
    public.profiles
  cascade;

  delete from public.categories where is_preset = false;
  perform public._seed_preset_categories();
end;
$$;

create or replace function public.cleanup_old_data(
  audit_keep_days integer default 365,
  trash_keep_days integer default 30
)
returns table (audit_deleted bigint, transactions_purged bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit bigint;
  v_tx    bigint;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Keine Admin-Rechte';
  end if;

  delete from public.audit_log
    where at < now() - make_interval(days => greatest(audit_keep_days, 0));
  get diagnostics v_audit = row_count;

  delete from public.transactions
    where deleted_at is not null
      and deleted_at < now() - make_interval(days => greatest(trash_keep_days, 0));
  get diagnostics v_tx = row_count;

  return query select v_audit, v_tx;
end;
$$;

-- (1) EXECUTE von den öffentlich erreichbaren Rollen entziehen.
revoke execute on function public.admin_wipe_data()                     from anon, authenticated, public;
revoke execute on function public.admin_factory_reset()                 from anon, authenticated, public;
revoke execute on function public.cleanup_old_data(integer, integer)    from anon, authenticated, public;
revoke execute on function public._seed_preset_categories()             from anon, authenticated, public;
-- get_storage_stats bleibt für Angemeldete lesbar (nur DB-/Storage-Größe),
-- aber nicht mehr für anonyme Aufrufer.
revoke execute on function public.get_storage_stats()                   from anon, public;

-- service_role behält (bzw. erhält) den Zugriff für die Edge Functions.
grant execute on function public.admin_wipe_data()                  to service_role;
grant execute on function public.admin_factory_reset()              to service_role;
grant execute on function public.cleanup_old_data(integer, integer) to service_role;
grant execute on function public._seed_preset_categories()          to service_role;
grant execute on function public.get_storage_stats()                to authenticated;
