-- =====================================================================
-- Money-Manager · 0021_retention_cleanup.sql · Automatische Aufräumung
-- =====================================================================
-- Zwei Tabellen wachsen sonst ungebremst:
--   * audit_log         — jeder Buchungs-Change erzeugt eine Zeile.
--   * transactions im Papierkorb (deleted_at gesetzt) bleiben liegen.
--
-- cleanup_old_data() hält beide schlank, ein täglicher pg_cron-Lauf um
-- 03:00 UTC ruft sie auf. Aktive Buchungen (deleted_at is null) werden
-- NIE angefasst. In Umgebungen ohne pg_cron wird die Planung übersprungen.
-- =====================================================================

create or replace function public.cleanup_old_data(
  audit_keep_days integer default 365,
  trash_keep_days integer default 30
)
returns table (audit_deleted bigint, trash_purged bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_audit bigint;
  v_trash bigint;
begin
  -- 1) Alte Audit-Log-Einträge entfernen.
  delete from public.audit_log
   where at < now() - make_interval(days => audit_keep_days);
  get diagnostics v_audit = row_count;

  -- 2) Buchungen im Papierkorb endgültig löschen. Splits + Kommentare gehen
  --    per ON DELETE CASCADE automatisch mit. Aktive Buchungen bleiben.
  delete from public.transactions
   where deleted_at is not null
     and deleted_at < now() - make_interval(days => trash_keep_days);
  get diagnostics v_trash = row_count;

  audit_deleted := v_audit;
  trash_purged  := v_trash;
  return next;
end;
$$;

-- Nur Owner/Scheduler dürfen das aufrufen, nicht normale (authenticated) Nutzer.
revoke all on function public.cleanup_old_data(integer, integer) from public;

-- Täglicher Lauf um 03:00 UTC – nur wenn pg_cron installiert ist. Der benannte
-- cron.schedule-Aufruf ersetzt einen evtl. vorhandenen Job gleichen Namens
-- (idempotent, mehrfach ausführbar).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'cleanup-old-data',
      '0 3 * * *',
      $cron$ select public.cleanup_old_data(); $cron$
    );
  end if;
end $$;
