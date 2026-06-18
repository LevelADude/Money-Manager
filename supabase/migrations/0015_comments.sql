-- =====================================================================
-- Money-Manager · 0015_comments.sql · Kommentare an Buchungen
-- =====================================================================
-- Kommentar-Thread je Buchung (Rückfragen klären). Gruppenweit geteilt.
-- =====================================================================

create table if not exists public.transaction_comments (
  id             uuid        primary key default gen_random_uuid(),
  transaction_id uuid        not null references public.transactions(id) on delete cascade,
  author         uuid        references public.profiles(id) on delete set null default auth.uid(),
  body           text        not null,
  created_at     timestamptz not null default now()
);
create index if not exists transaction_comments_tx_idx
  on public.transaction_comments(transaction_id);

alter table public.transaction_comments enable row level security;
drop policy if exists transaction_comments_all on public.transaction_comments;
create policy transaction_comments_all on public.transaction_comments
  for all to authenticated using (true) with check (true);

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  begin
    alter publication supabase_realtime add table public.transaction_comments;
  exception when duplicate_object then null; end;
end $$;
