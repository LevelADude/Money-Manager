-- 0033: Währungen + Wechselkurse pro Besitzer in die DB.
--
-- Bisher lagen eigene Währungscodes und Wechselkurse nur lokal pro Gerät
-- (SharedPreferences). Folgen: (a) fremde Währungen tauchten über sichtbare
-- Konten in der eigenen Liste auf, (b) fremde Konten wurden 1:1 gerechnet, weil
-- der Kurs des Besitzers das eigene Gerät nie erreichte.
--
-- Neu: Tabelle `currencies` je Besitzer (owner_id) mit Kurs zur Basiswährung des
-- Besitzers. Damit kann ein Betrachter fremde Konten mit den Kursen des
-- Besitzers anzeigen. Die Basiswährung je Nutzer wandert nach
-- profiles.base_currency, damit ein Kurs korrekt interpretiert werden kann.

alter table public.profiles
  add column if not exists base_currency text not null default 'EUR';

create table if not exists public.currencies (
  owner_id     uuid not null references public.profiles(id) on delete cascade
                 default auth.uid(),
  code         text not null,
  -- Einheiten der BASISWÄHRUNG DES BESITZERS je 1 Einheit `code`.
  -- null = noch kein Kurs gesetzt.
  rate_to_base numeric,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  primary key (owner_id, code)
);

alter table public.currencies enable row level security;

-- Lesen: Besitzer + Personen mit Freigabe (brauchen die Kurse zur Anzeige der
-- freigegebenen Konten). Schreiben: nur der Besitzer.
drop policy if exists currencies_select on public.currencies;
drop policy if exists currencies_modify on public.currencies;
create policy currencies_select on public.currencies for select
  using (public.can_view_owner(owner_id));
create policy currencies_modify on public.currencies for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop trigger if exists currencies_set_updated_at on public.currencies;
create trigger currencies_set_updated_at before update on public.currencies
  for each row execute function public.set_updated_at();
