-- =====================================================================
-- Money-Manager · 0030_admin_list_user_emails.sql · E-Mails für Admins
-- =====================================================================
-- public.profiles speichert keine E-Mail (die liegt nur in auth.users, das
-- der Client normalerweise nicht abfragen kann). Admins konnten im
-- "Nutzer"-Bereich daher nur den selbstgewählten Anzeigenamen sehen, nicht
-- wem ein Konto wirklich gehört. Diese admin-only Funktion macht die
-- E-Mail-Zuordnung für Admins sichtbar (security definer, prüft is_admin()).
-- =====================================================================

create or replace function public.admin_list_user_emails()
returns table (id uuid, email text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Keine Admin-Rechte';
  end if;
  return query select u.id, u.email::text from auth.users u;
end;
$$;
revoke all on function public.admin_list_user_emails() from public;
grant execute on function public.admin_list_user_emails() to authenticated;
