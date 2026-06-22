-- =====================================================================
-- Money-Manager · 0024_archived_years.sql · Archivierung alter Jahre
-- =====================================================================
-- Alte Jahre werden nach GitHub ausgelagert (verschlüsselt, via Edge
-- Function archive-proxy), um DB-/Storage-Speicher freizugeben. Diese
-- Tabelle ist der MARKER, welche Jahre ausgelagert sind, plus pro Konto der
-- Carry-over (Eröffnungssaldo), damit die laufenden Kontostände nach dem
-- Löschen der Buchungen korrekt bleiben.
--
-- carryover_by_account: { "<account_id>": <cents>, ... } – Summe der
--   vorzeichenbehafteten Beträge der ausgelagerten Buchungen je Konto
--   (inkl. Übertrags-Beine). Wird in der App zum Saldo addiert.
--
-- purge_year_data(): löscht die Buchungen eines Jahres ENDGÜLTIG (Splits/
--   Kommentare via FK-Cascade). Nur Admins. Der Audit-Trigger wird dabei
--   ausgesetzt, sonst würde audit_log die Massenlöschung 1:1 spiegeln und
--   den freigegebenen Speicher wieder auffressen.
-- =====================================================================

create table if not exists public.archived_years (
  year                 int         primary key,
  archived_at          timestamptz not null default now(),
  archived_by          uuid        references public.profiles(id) on delete set null default auth.uid(),
  tx_count             int         not null default 0,
  byte_size            bigint      not null default 0,
  carryover_by_account jsonb       not null default '{}'::jsonb,
  github_path          text,
  checksum             text
);

alter table public.archived_years enable row level security;

-- Lesen: alle Angemeldeten (für read-only-Anzeige + Saldo-Carry-over).
drop policy if exists archived_years_select on public.archived_years;
create policy archived_years_select on public.archived_years
  for select to authenticated using (true);

-- Schreiben/Ändern/Löschen: nur Admins (Archivieren ist destruktiv).
drop policy if exists archived_years_admin_write on public.archived_years;
create policy archived_years_admin_write on public.archived_years
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.archived_years;
  exception when duplicate_object then null; end;
end $$;

-- Audit-Trigger so erweitern, dass er bei gesetztem GUC app.skip_audit='on'
-- nichts protokolliert. Die Massenlöschung beim Archivieren würde sonst für
-- JEDE Buchung eine 'purge'-Zeile (mit voller Buchung als jsonb) in audit_log
-- schreiben und den gerade freigegebenen Speicher wieder auffressen.
-- (Funktional identisch zu 0014, nur um den Skip-Check ergänzt.)
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
  if current_setting('app.skip_audit', true) = 'on' then
    return null;
  end if;
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

-- --- Endgültiges Löschen eines Jahres -------------------------------
-- Wird von der App NACH bestätigtem Push nach GitHub aufgerufen. Gibt die
-- Anzahl gelöschter Buchungen zurück. Admin-Guard, da security definer RLS
-- umgeht. set_config(..., true) gilt nur transaktionslokal.
create or replace function public.purge_year_data(p_year int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
begin
  if not public.is_admin() then
    raise exception 'Nur Admins dürfen Jahre archivieren/löschen.';
  end if;

  -- Audit für diese Transaktion aussetzen.
  perform set_config('app.skip_audit', 'on', true);

  -- Bestehende Audit-Einträge der betroffenen Buchungen entfernen (Speicher).
  delete from public.audit_log
  where table_name = 'transactions'
    and row_id in (
      select id from public.transactions
      where extract(year from occurred_on) = p_year
    );

  -- Buchungen löschen (transaction_splits/-_comments via FK-Cascade).
  delete from public.transactions
  where extract(year from occurred_on) = p_year;
  get diagnostics v_count = row_count;

  return v_count;
end;
$$;
revoke all on function public.purge_year_data(int) from public;
grant execute on function public.purge_year_data(int) to authenticated;
