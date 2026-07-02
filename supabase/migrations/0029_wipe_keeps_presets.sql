-- =====================================================================
-- Money-Manager · 0029_wipe_keeps_presets.sql · Presets bei Wipe erhalten
-- =====================================================================
-- Bug: admin_wipe_data()/admin_factory_reset() truncateten bislang auch
-- public.categories komplett, inkl. der Preset-Kategorien (is_preset=true).
-- Erwartung ist aber "Zustand wie Neuinstallation" — eine echte
-- Neuinstallation (setup.sql auf leerer DB) saet die Presets immer mit.
-- Fix: nur nutzerdefinierte Kategorien (is_preset=false) gelten als
-- Testdaten und werden entfernt; Presets bleiben erhalten bzw. werden neu
-- gesaet, falls doch keine vorhanden sind.
-- =====================================================================

-- --- Helfer: Presets saeen, falls keine vorhanden (wie setup.sql) -------
create or replace function public._seed_preset_categories()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.categories where is_preset) then
    insert into public.categories (name, kind, is_preset, icon) values
      -- Ausgaben
      ('Lebensmittel','expense',true,'cart'),
      ('Restaurant & Café','expense',true,'restaurant'),
      ('Haushalt','expense',true,'home_supplies'),
      ('Wohnen & Miete','expense',true,'home'),
      ('Nebenkosten (Strom/Gas/Wasser)','expense',true,'bolt'),
      ('Internet & Telefon','expense',true,'wifi'),
      ('Auto & Tanken','expense',true,'car'),
      ('ÖPNV & Transport','expense',true,'bus'),
      ('Versicherungen','expense',true,'shield'),
      ('Gesundheit & Apotheke','expense',true,'health'),
      ('Kleidung','expense',true,'shirt'),
      ('Freizeit & Hobby','expense',true,'sports'),
      ('Abos & Streaming','expense',true,'subscription'),
      ('Reisen & Urlaub','expense',true,'flight'),
      ('Geschenke','expense',true,'gift'),
      ('Bildung','expense',true,'school'),
      ('Haustier','expense',true,'pet'),
      ('Kinder','expense',true,'child'),
      ('Spenden','expense',true,'donate'),
      ('Steuern & Gebühren','expense',true,'tax'),
      ('Sparen & Investieren','expense',true,'savings'),
      ('Sonstiges','expense',true,'more'),
      -- Einnahmen
      ('Gehalt & Lohn','income',true,'salary'),
      ('Bonus','income',true,'star'),
      ('Selbstständigkeit','income',true,'work'),
      ('Zinsen & Dividenden','income',true,'invest'),
      ('Erstattung','income',true,'refund'),
      ('Verkauf','income',true,'sale'),
      ('Geschenk erhalten','income',true,'gift'),
      ('Kindergeld','income',true,'child'),
      ('Sonstiges','income',true,'more');
  end if;
end;
$$;
revoke all on function public._seed_preset_categories() from public;
grant execute on function public._seed_preset_categories() to service_role;

-- --- Nur Daten leeren (Nutzer/Whitelist bleiben) -------------------------
create or replace function public.admin_wipe_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log
  cascade;

  delete from public.categories where is_preset = false;
  perform public._seed_preset_categories();
end;
$$;
revoke all on function public.admin_wipe_data() from public;
grant execute on function public.admin_wipe_data() to service_role;

-- --- Werkszustand (alles weg, auch Profile + Whitelist) ------------------
create or replace function public.admin_factory_reset()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  truncate table
    public.transaction_comments,
    public.transaction_splits,
    public.transactions,
    public.account_members,
    public.access_grants,
    public.accounts,
    public.category_rules,
    public.budgets,
    public.recurring_rules,
    public.savings_goals,
    public.transaction_templates,
    public.audit_log,
    public.allowed_emails,
    public.profiles
  cascade;

  delete from public.categories where is_preset = false;
  perform public._seed_preset_categories();
end;
$$;
revoke all on function public.admin_factory_reset() from public;
grant execute on function public.admin_factory_reset() to service_role;
