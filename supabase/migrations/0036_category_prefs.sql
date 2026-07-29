-- 0036: Per-Nutzer-Einstellungen für Kategorien (Reihenfolge / aktiv / ausgeblendet).
--
-- Bisher waren Preset-Kategorien (owner_id = null) nur für Admins änderbar
-- (siehe 0032). Dadurch konnten normale Nutzer Presets weder deaktivieren noch
-- umsortieren noch „löschen" — die Writes schlugen still fehl (RLS, 0 Zeilen).
--
-- Statt die geteilten Preset-Zeilen für alle veränderbar zu machen, bekommt
-- jeder Nutzer eine eigene Overlay-Tabelle. So kann jede Person ihre Kategorien
-- (Presets UND eigene) individuell sortieren, aktiv/inaktiv schalten und für
-- sich ausblenden, ohne die Ansicht anderer Nutzer zu verändern.
--
-- Wirksamer Wert im Client: prefs.<feld> falls gesetzt, sonst categories.<feld>.
-- hidden = true blendet die Kategorie in Listen/Auswahlen aus (reversibel).

create table if not exists public.category_prefs (
  owner_id    uuid not null references public.profiles(id) on delete cascade
                default auth.uid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  active      boolean,           -- null = erbt categories.active
  sort_order  integer,           -- null = erbt categories.sort_order
  hidden      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (owner_id, category_id)
);
create index if not exists category_prefs_owner_idx
  on public.category_prefs(owner_id);

alter table public.category_prefs enable row level security;

-- Rein persönlich: nur der Besitzer sieht/ändert seine eigenen Overlays.
drop policy if exists category_prefs_select on public.category_prefs;
drop policy if exists category_prefs_modify on public.category_prefs;
create policy category_prefs_select on public.category_prefs for select
  using (owner_id = auth.uid());
create policy category_prefs_modify on public.category_prefs for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop trigger if exists category_prefs_set_updated_at on public.category_prefs;
create trigger category_prefs_set_updated_at before update on public.category_prefs
  for each row execute function public.set_updated_at();

-- Realtime, damit Änderungen ohne Neuladen greifen.
do $$
begin
  begin
    alter publication supabase_realtime add table public.category_prefs;
  exception when duplicate_object then null;
  end;
end $$;
