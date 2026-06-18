-- =====================================================================
-- Money-Manager · 0017_category_rules.sql · Auto-Kategorisierungs-Regeln
-- =====================================================================
-- Regeln "Titel enthält <Stichwort> -> Kategorie". Gruppenweit geteilt.
-- Werden beim Erfassen automatisch angewandt.
-- =====================================================================

create table if not exists public.category_rules (
  id          uuid        primary key default gen_random_uuid(),
  keyword     text        not null,
  category_id uuid        not null references public.categories(id) on delete cascade,
  created_by  uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at  timestamptz not null default now()
);

alter table public.category_rules enable row level security;
drop policy if exists category_rules_all on public.category_rules;
create policy category_rules_all on public.category_rules
  for all to authenticated using (true) with check (true);

-- read_only-Schreibsperre konsistent mitnehmen (falls is_writer existiert).
do $$
begin
  if exists (select 1 from pg_proc where proname = 'is_writer') then
    execute 'drop policy if exists category_rules_ro_ins on public.category_rules';
    execute 'create policy category_rules_ro_ins on public.category_rules as restrictive for insert to authenticated with check (public.is_writer())';
    execute 'drop policy if exists category_rules_ro_upd on public.category_rules';
    execute 'create policy category_rules_ro_upd on public.category_rules as restrictive for update to authenticated using (public.is_writer()) with check (public.is_writer())';
    execute 'drop policy if exists category_rules_ro_del on public.category_rules';
    execute 'create policy category_rules_ro_del on public.category_rules as restrictive for delete to authenticated using (public.is_writer())';
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.category_rules;
  exception when duplicate_object then null; end;
end $$;
