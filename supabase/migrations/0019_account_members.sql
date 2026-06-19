-- 0019: Geteilte Konten (Gemeinschaftskonto).
-- Ein Konto gehört weiterhin einem Besitzer (owner_id), kann aber Mitglieder
-- haben. Mitglieder dürfen das Konto SEHEN und darauf BUCHEN (wie ein echtes
-- Gemeinschaftskonto). Das Konto selbst (umbenennen/löschen) bleibt dem
-- Besitzer (bzw. seinen manage-Freigaben) vorbehalten.

create table if not exists public.account_members (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (account_id, user_id)
);
alter table public.account_members enable row level security;

-- Ist der aktuelle Nutzer Besitzer des Kontos? (definer -> umgeht RLS)
create or replace function public.is_account_owner(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and a.owner_id = auth.uid());
$$;

-- Sicht/Verwaltung eines Kontos: Besitzer/Freigabe ODER Mitglied.
create or replace function public.can_view_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_view_owner(a.owner_id))
      or exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

create or replace function public.can_manage_account(acc uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.accounts a
                 where a.id = acc and public.can_manage_owner(a.owner_id))
      or exists (select 1 from public.account_members m
                 where m.account_id = acc and m.user_id = auth.uid());
$$;

-- accounts: Mitglieder dürfen das geteilte Konto sehen (Bearbeiten/Löschen des
-- Kontos selbst bleibt bei Besitzer + manage-Freigaben).
drop policy if exists accounts_select on public.accounts;
create policy accounts_select on public.accounts for select
  using (public.can_view_account(id));

-- account_members: Besitzer sieht/verwaltet die Mitgliederliste; jede:r sieht
-- die eigene Mitgliedschaft.
drop policy if exists am_select on public.account_members;
drop policy if exists am_modify on public.account_members;
create policy am_select on public.account_members for select
  using (public.is_account_owner(account_id) or user_id = auth.uid());
create policy am_modify on public.account_members for all
  using (public.is_account_owner(account_id))
  with check (public.is_account_owner(account_id));
