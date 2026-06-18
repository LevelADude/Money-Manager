-- =====================================================================
-- Money-Manager · 0014_audit_log.sql · Änderungsverlauf (Audit-Log)
-- =====================================================================
-- Protokolliert Anlegen/Ändern/Löschen/Wiederherstellen von Buchungen
-- (wer/wann/was) per Trigger. Speist Buchungs-Verlauf + Aktivitäts-Feed.
-- =====================================================================

create table if not exists public.audit_log (
  id         bigint generated always as identity primary key,
  table_name text        not null,
  row_id     uuid,
  action     text        not null,
  actor      uuid,
  data       jsonb,
  at         timestamptz not null default now()
);
create index if not exists audit_log_row_idx on public.audit_log(row_id);
create index if not exists audit_log_at_idx on public.audit_log(at desc);

alter table public.audit_log enable row level security;
drop policy if exists audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log
  for select to authenticated using (true);

-- Schreiben nur über den Trigger (SECURITY DEFINER), nicht direkt durch Nutzer.
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

drop trigger if exists trg_audit_transactions on public.transactions;
create trigger trg_audit_transactions
  after insert or update or delete on public.transactions
  for each row execute function public.log_transaction_change();

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.audit_log;
  exception when duplicate_object then null; end;
end $$;
