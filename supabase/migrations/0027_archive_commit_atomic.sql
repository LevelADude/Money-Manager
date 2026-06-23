-- =====================================================================
-- Money-Manager · 0027_archive_commit_atomic.sql
-- =====================================================================
-- Atomare Jahres-Archivierung: schreibt den Marker (+ Carry-over) UND loescht
-- die Jahresdaten in EINER Transaktion. Bisher waren das zwei Schritte vom
-- Client aus (Marker-Upsert, dann purge_year_data) -> bei einem Abbruch
-- dazwischen war der Carry-over schon aktiv, die Buchungen aber noch da
-- (kurzzeitige Doppelzaehlung des Saldos). Eine SQL-Funktion laeuft in einer
-- Transaktion und ist daher atomar.
-- =====================================================================

create or replace function public.archive_commit_year(
  p_year        int,
  p_tx_count    int,
  p_byte_size   bigint,
  p_carryover   jsonb,
  p_github_path text
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    raise exception 'Nur Admins duerfen archivieren.';
  end if;

  -- Audit-Trigger fuer diese Transaktion stummschalten (wie purge_year_data).
  perform set_config('app.skip_audit', 'on', true);

  -- 1) Marker + Carry-over schreiben (archived_by via Spalten-Default = auth.uid()).
  insert into public.archived_years
    (year, tx_count, byte_size, carryover_by_account, github_path, archived_at)
  values
    (p_year, p_tx_count, p_byte_size, coalesce(p_carryover, '{}'::jsonb),
     p_github_path, now())
  on conflict (year) do update set
    tx_count             = excluded.tx_count,
    byte_size            = excluded.byte_size,
    carryover_by_account = excluded.carryover_by_account,
    github_path          = excluded.github_path,
    archived_at          = now();

  -- 2) Jahresdaten endgueltig loeschen (Splits/Kommentare via ON DELETE CASCADE).
  delete from public.audit_log
   where table_name = 'transactions'
     and row_id in (
       select id from public.transactions
       where extract(year from occurred_on) = p_year
     );
  delete from public.transactions
   where extract(year from occurred_on) = p_year;
end;
$$;
revoke all on function public.archive_commit_year(int, int, bigint, jsonb, text) from public;
grant execute on function public.archive_commit_year(int, int, bigint, jsonb, text) to authenticated;
