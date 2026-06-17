-- =====================================================================
-- Money-Manager · 0007_admin_whitelist.sql · Admin-Rechte + E-Mail-Whitelist
-- =====================================================================
-- - profiles.is_admin (1. Nutzer wird automatisch Admin)
-- - allowed_emails: nur freigeschaltete E-Mails dürfen sich registrieren
--   (serverseitig per Trigger erzwungen)
-- - is_admin()-Helfer + Admin-Policies
-- =====================================================================

alter table public.profiles add column if not exists is_admin boolean not null default false;

-- Helfer: Ist der aktuelle Nutzer Admin? (für RLS-Policies)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;
grant execute on function public.is_admin() to authenticated;

-- Whitelist-Tabelle
create table if not exists public.allowed_emails (
  email      text primary key,
  added_by   uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
alter table public.allowed_emails enable row level security;
drop policy if exists allowed_emails_admin on public.allowed_emails;
create policy allowed_emails_admin on public.allowed_emails
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Profil beim Signup anlegen; erster Nutzer wird Admin.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, is_admin)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    not exists (select 1 from public.profiles where is_admin = true)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Falls bereits Nutzer existieren, aber noch kein Admin: ältesten zum Admin machen.
update public.profiles set is_admin = true
where id = (select id from public.profiles order by created_at asc limit 1)
  and not exists (select 1 from public.profiles where is_admin = true);

-- Registrierungs-Sperre: nur Whitelist-E-Mails (erster Nutzer als Bootstrap erlaubt).
create or replace function public.enforce_email_whitelist()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from auth.users) = 0 then
    return new;
  end if;
  if exists (select 1 from public.allowed_emails where lower(email) = lower(new.email)) then
    return new;
  end if;
  raise exception 'E-Mail nicht freigeschaltet. Bitte den Administrator kontaktieren.';
end;
$$;
revoke execute on function public.enforce_email_whitelist() from public, anon, authenticated;

drop trigger if exists on_auth_user_whitelist on auth.users;
create trigger on_auth_user_whitelist
  before insert on auth.users
  for each row execute function public.enforce_email_whitelist();

-- Admins dürfen jedes Profil ändern (z. B. is_admin setzen).
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
