-- =====================================================================
-- Money-Manager · 0022_owner_role.sql · Geschützte Besitzer-Rolle
-- =====================================================================
-- Die ERSTE registrierte Person ist der "Besitzer" (is_owner): immer Admin,
-- kann von niemandem degradiert, auf "nur Lesen" gesetzt oder gelöscht werden.
-- Normale Admins darunter bleiben frei verwaltbar. Genau ein Besitzer.
-- =====================================================================

alter table public.profiles
  add column if not exists is_owner boolean not null default false;

-- Helfer: Ist der aktuelle Nutzer der Besitzer? (für RLS/Trigger/Guards)
create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_owner from public.profiles where id = auth.uid()), false);
$$;
grant execute on function public.is_owner() to authenticated;

-- Profil beim Signup anlegen; die allererste Person wird Besitzer UND Admin,
-- jede weitere Person, solange noch kein Admin existiert, wird Admin.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_first boolean := not exists (select 1 from public.profiles);
begin
  insert into public.profiles (id, display_name, is_admin, is_owner)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    v_first or not exists (select 1 from public.profiles where is_admin = true),
    v_first
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Backfill: ältestes Profil zum Besitzer machen, falls noch keiner existiert.
-- MUSS vor dem Schutz-Trigger laufen (sonst würde dieser das Setzen blocken).
update public.profiles set is_owner = true
where id = (select id from public.profiles order by created_at asc limit 1)
  and not exists (select 1 from public.profiles where is_owner = true);

-- Schutz-Trigger: Besitzer kann nicht degradiert/gesperrt/gelöscht werden und
-- der Besitzer-Status kann nicht an andere übertragen werden.
-- (TRUNCATE umgeht Row-Trigger — vom Werks-Reset in 0023 bewusst genutzt.)
create or replace function public.protect_owner()
returns trigger language plpgsql set search_path = public as $$
begin
  if (tg_op = 'DELETE') then
    if old.is_owner then
      raise exception 'Der Besitzer kann nicht gelöscht werden.';
    end if;
    return old;
  end if;
  -- UPDATE
  if old.is_owner and (not new.is_owner or not new.is_admin or new.read_only) then
    raise exception 'Der Besitzer kann nicht degradiert oder gesperrt werden.';
  end if;
  if new.is_owner and not old.is_owner then
    raise exception 'Der Besitzer-Status kann nicht übertragen werden.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_owner on public.profiles;
create trigger trg_protect_owner
  before update or delete on public.profiles
  for each row execute function public.protect_owner();
