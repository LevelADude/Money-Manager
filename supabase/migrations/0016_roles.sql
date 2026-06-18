-- =====================================================================
-- Money-Manager · 0016_roles.sql · Nur-Lesen-Rolle
-- =====================================================================
-- Mitglieder können auf "nur lesen" gesetzt werden (read_only). Solche
-- Nutzer dürfen weiterhin alles sehen, aber keine Daten mehr schreiben.
-- Durchgesetzt per RESTRICTIVE-Policies (zusätzlich zu den bestehenden).
-- =====================================================================

alter table public.profiles
  add column if not exists read_only boolean not null default false;

-- true, wenn der aktuelle Nutzer schreiben darf (nicht read_only).
create or replace function public.is_writer()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not coalesce(
    (select read_only from public.profiles where id = auth.uid()), false);
$$;

-- Schreibrechte für read_only-Nutzer auf den Datentabellen sperren.
do $$
declare
  t text;
  tbls text[] := array[
    'transactions','accounts','categories','budgets','recurring_rules',
    'transaction_splits','savings_goals','transaction_templates',
    'transaction_comments'
  ];
begin
  foreach t in array tbls loop
    execute format('drop policy if exists %I on public.%I', t||'_ro_ins', t);
    execute format('create policy %I on public.%I as restrictive for insert to authenticated with check (public.is_writer())', t||'_ro_ins', t);
    execute format('drop policy if exists %I on public.%I', t||'_ro_upd', t);
    execute format('create policy %I on public.%I as restrictive for update to authenticated using (public.is_writer()) with check (public.is_writer())', t||'_ro_upd', t);
    execute format('drop policy if exists %I on public.%I', t||'_ro_del', t);
    execute format('create policy %I on public.%I as restrictive for delete to authenticated using (public.is_writer())', t||'_ro_del', t);
  end loop;
end $$;
