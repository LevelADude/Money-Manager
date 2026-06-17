-- =====================================================================
-- Money-Manager · 0005_recurring.sql · Wiederkehrende Buchungen
-- =====================================================================
-- Regeln für Daueraufträge (Miete, Gehalt, Abos …). Die App erzeugt fällige
-- Buchungen race-sicher (atomares "Beanspruchen" der Periode vor dem Anlegen).
-- =====================================================================

create table if not exists public.recurring_rules (
  id                  uuid    primary key default gen_random_uuid(),
  account_id          uuid    not null references public.accounts(id) on delete cascade,
  type                text    not null check (type in ('expense','income','transfer')),
  amount_cents        bigint  not null check (amount_cents >= 0),
  category_id         uuid    references public.categories(id) on delete set null,
  transfer_account_id uuid    references public.accounts(id) on delete cascade,
  title               text    not null default '',
  note                text    not null default '',
  interval_unit       text    not null check (interval_unit in ('day','week','month','year')),
  interval_count      int     not null default 1 check (interval_count >= 1),
  next_due            date    not null,
  end_date            date,
  active              boolean not null default true,
  created_by          uuid    references public.profiles(id) on delete set null default auth.uid(),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint rec_transfer_needs_target check (
    (type =  'transfer' and transfer_account_id is not null and transfer_account_id <> account_id)
    or
    (type <> 'transfer' and transfer_account_id is null)
  )
);
create index if not exists recurring_next_due_idx on public.recurring_rules(next_due);
create index if not exists recurring_updated_idx  on public.recurring_rules(updated_at);

drop trigger if exists recurring_set_updated_at on public.recurring_rules;
create trigger recurring_set_updated_at before update on public.recurring_rules
  for each row execute function public.set_updated_at();

alter table public.recurring_rules enable row level security;
drop policy if exists recurring_all on public.recurring_rules;
create policy recurring_all on public.recurring_rules
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin alter publication supabase_realtime add table public.recurring_rules; exception when duplicate_object then null; end;
end $$;
