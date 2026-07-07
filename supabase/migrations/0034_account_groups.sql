-- 0034: Eigene Konten-Gruppen für Custom-Summen (z. B. „Deutsche Konten",
-- „Alle Sparkonten"). Pro Nutzer privat; die App summiert die Salden der
-- gewählten Konten und zeigt sie zusätzlich zum Gesamtvermögen an.

create table if not exists public.account_groups (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references public.profiles(id) on delete cascade
                default auth.uid(),
  name        text not null,
  account_ids uuid[] not null default '{}',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.account_groups enable row level security;

-- Rein privat: nur der Besitzer sieht/ändert seine Gruppen.
drop policy if exists account_groups_select on public.account_groups;
drop policy if exists account_groups_modify on public.account_groups;
create policy account_groups_select on public.account_groups for select
  using (owner_id = auth.uid());
create policy account_groups_modify on public.account_groups for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop trigger if exists account_groups_set_updated_at on public.account_groups;
create trigger account_groups_set_updated_at before update on public.account_groups
  for each row execute function public.set_updated_at();
