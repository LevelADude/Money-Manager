-- 0020: Fix - „Konto anlegen" schlug mit RLS-Fehler (42501) fehl.
--
-- Ursache: In 0019 wurde accounts_select auf can_view_account(id) umgestellt.
-- Diese Funktion fragt die accounts-Tabelle SELBST ab. Bei INSERT ... RETURNING
-- (die App holt die neue id zurück) ist die gerade eingefügte Zeile für diese
-- Unterabfrage noch nicht sichtbar -> die SELECT-Policy schlägt fehl -> 42501.
--
-- Fix: accounts_select prüft direkt die Spalten der Zeile (owner_id) + Freigabe
-- + Mitgliedschaft, OHNE accounts erneut abzufragen. is_account_member() kapselt
-- die Mitgliedschaftsprüfung (eigene Tabelle, kein Self-Query auf accounts).

create or replace function public.is_account_member(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select
  using (public.can_view_owner(owner_id) or public.is_account_member(id));
