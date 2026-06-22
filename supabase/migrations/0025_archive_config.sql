-- =====================================================================
-- Money-Manager · 0025_archive_config.sql · Archiv-Repo-Verbindung
-- =====================================================================
-- Pro App-Instanz EIN Archiv-Repo (siehe 0024). Repo-URL + GitHub-Token +
-- Verschlüsselungs-Schlüssel werden hier SERVERSEITIG gehalten und NUR von der
-- Edge Function archive-proxy (service_role) gelesen. Der Client sieht Token &
-- Schlüssel NIE – er bekommt nur den Status über get_archive_config_status().
--
-- Warum nicht als Function-Secret? Damit jeder Fork-Betreiber sein eigenes
-- Repo direkt IN DER APP einrichten kann (kein CLI nötig), auch im Web-Build,
-- ohne dass das Token jemals in den (öffentlichen) Client gelangt.
-- =====================================================================

create table if not exists public.archive_config (
  id           smallint    primary key default 1 check (id = 1),
  github_repo  text,
  github_token text,
  enc_key      text,
  updated_at   timestamptz not null default now(),
  updated_by   uuid        references public.profiles(id) on delete set null
);

-- RLS an, aber KEINE Policy für authenticated: kein direkter Client-Zugriff.
-- Zugriff ausschließlich über die SECURITY-DEFINER-RPCs unten (Status/Setzen/
-- Trennen) bzw. über service_role in der Edge Function (umgeht RLS).
alter table public.archive_config enable row level security;

-- Status OHNE Geheimnisse – für alle Angemeldeten lesbar (UI-Anzeige).
create or replace function public.get_archive_config_status()
returns table (configured boolean, github_repo text, has_token boolean, has_key boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(c.github_repo, '') <> ''
      and coalesce(c.github_token, '') <> ''
      and coalesce(c.enc_key, '') <> ''                         as configured,
    c.github_repo                                               as github_repo,
    coalesce(c.github_token, '') <> ''                          as has_token,
    coalesce(c.enc_key, '') <> ''                               as has_key
  from (select 1) d
  left join public.archive_config c on c.id = 1;
$$;
revoke all on function public.get_archive_config_status() from public;
grant execute on function public.get_archive_config_status() to authenticated;

-- Setzen/Ändern – nur Admin. Leere Felder lassen den bisherigen Wert stehen
-- (z. B. Repo ändern, ohne Token erneut einzugeben).
create or replace function public.set_archive_config(
  p_repo text, p_token text, p_enc_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Nur Admins dürfen das Archiv-Repo einrichten.';
  end if;
  insert into public.archive_config (id, github_repo, github_token, enc_key, updated_at, updated_by)
  values (1, nullif(trim(p_repo), ''), nullif(p_token, ''), nullif(p_enc_key, ''), now(), auth.uid())
  on conflict (id) do update set
    github_repo  = coalesce(excluded.github_repo,  public.archive_config.github_repo),
    github_token = coalesce(excluded.github_token, public.archive_config.github_token),
    enc_key      = coalesce(excluded.enc_key,      public.archive_config.enc_key),
    updated_at   = now(),
    updated_by   = auth.uid();
end;
$$;
revoke all on function public.set_archive_config(text, text, text) from public;
grant execute on function public.set_archive_config(text, text, text) to authenticated;

-- Trennen – nur Admin. Entfernt Repo/Token/Schlüssel.
create or replace function public.clear_archive_config()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Nur Admins dürfen das Archiv-Repo trennen.';
  end if;
  delete from public.archive_config where id = 1;
end;
$$;
revoke all on function public.clear_archive_config() from public;
grant execute on function public.clear_archive_config() to authenticated;
