-- =====================================================================
-- Money-Manager · 0012_templates.sql · Buchungs-Vorlagen (Favoriten)
-- =====================================================================
-- Wiederverwendbare Vorlagen für häufige Buchungen (z. B. „Wocheneinkauf").
-- Gruppenweit geteilt. Keine Auswirkung auf Salden – nur zum Vorbefüllen.
-- =====================================================================

create table if not exists public.transaction_templates (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null,
  account_id   uuid        references public.accounts(id) on delete set null,
  type         text        not null default 'expense',
  amount_cents bigint      not null default 0,
  category_id  uuid        references public.categories(id) on delete set null,
  title        text        not null default '',
  note         text        not null default '',
  tags         text[]      not null default '{}',
  created_by   uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now()
);

alter table public.transaction_templates enable row level security;
drop policy if exists transaction_templates_all on public.transaction_templates;
create policy transaction_templates_all on public.transaction_templates
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.transaction_templates;
  exception when duplicate_object then null; end;
end $$;
