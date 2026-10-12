-- 0038: Reservierungen (zurückgelegtes Geld auf einem Konto).
--
-- Eine Reservierung bindet einen Betrag auf einem Konto (z. B. „Laptop nächsten
-- Monat"). Der Kontostand selbst bleibt unverändert; die App zieht offene
-- Reservierungen nur für den „verfügbaren" Betrag ab. Die Währung ist immer
-- die des Kontos.
--
-- Optional:
--   * due_on       – bis wann das Geld gebraucht wird (Fälligkeits-Hinweis).
--   * category_id  – wird beim Einlösen in die Ausgabe übernommen.
--   * topup_*      – wiederkehrende Rücklage: alle topup_unit wird der Betrag
--                    um topup_cents erhöht (gedeckelt auf target_cents).
--                    Der k-te Termin ist topup_start + k * Einheit (k ab 0),
--                    topup_count zählt die bereits angewendeten Termine. So
--                    driften Monatsenden nicht (31. → 28. → 31.).
--
-- Sichtbarkeit/Rechte wie bei Buchungen: wer das Konto sehen darf, sieht die
-- Reservierungen; wer es verwalten darf, darf sie ändern.

create table if not exists public.reservations (
  id           uuid        primary key default gen_random_uuid(),
  account_id   uuid        not null references public.accounts(id) on delete cascade,
  name         text        not null,
  amount_cents bigint      not null default 0 check (amount_cents >= 0),
  due_on       date,
  category_id  uuid        references public.categories(id) on delete set null,
  note         text        not null default '',
  target_cents bigint      check (target_cents is null or target_cents > 0),
  topup_cents  bigint      check (topup_cents is null or topup_cents > 0),
  topup_unit   text        check (topup_unit is null or topup_unit in ('week','month','year')),
  topup_start  date,
  topup_count  integer     not null default 0 check (topup_count >= 0),
  created_by   uuid        references public.profiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Wiederkehrend nur komplett (Betrag + Einheit + Start) oder gar nicht.
  constraint reservations_topup_complete check (
    (topup_cents is null and topup_unit is null and topup_start is null)
    or (topup_cents is not null and topup_unit is not null and topup_start is not null)
  )
);
create index if not exists reservations_account_idx
  on public.reservations(account_id);

alter table public.reservations enable row level security;

drop policy if exists reservations_select on public.reservations;
drop policy if exists reservations_insert on public.reservations;
drop policy if exists reservations_update on public.reservations;
drop policy if exists reservations_delete on public.reservations;
create policy reservations_select on public.reservations for select
  using (public.can_view_account(account_id));
create policy reservations_insert on public.reservations for insert
  with check (public.can_manage_account(account_id));
create policy reservations_update on public.reservations for update
  using (public.can_manage_account(account_id))
  with check (public.can_manage_account(account_id));
create policy reservations_delete on public.reservations for delete
  using (public.can_manage_account(account_id));

-- Nur-Lesen-Nutzer (0016) dürfen nichts schreiben.
drop policy if exists reservations_ro_ins on public.reservations;
drop policy if exists reservations_ro_upd on public.reservations;
drop policy if exists reservations_ro_del on public.reservations;
create policy reservations_ro_ins on public.reservations as restrictive
  for insert to authenticated with check (public.is_writer());
create policy reservations_ro_upd on public.reservations as restrictive
  for update to authenticated using (public.is_writer()) with check (public.is_writer());
create policy reservations_ro_del on public.reservations as restrictive
  for delete to authenticated using (public.is_writer());

drop trigger if exists reservations_set_updated_at on public.reservations;
create trigger reservations_set_updated_at before update on public.reservations
  for each row execute function public.set_updated_at();

-- Wiederkehrende Rücklagen fortschreiben. Läuft mit den Rechten des Aufrufers
-- (RLS greift), Zeilen werden gesperrt → zwei Geräte gleichzeitig buchen
-- keinen Termin doppelt. Liefert die Zahl der angewendeten Termine.
create or replace function public.apply_reservation_topups()
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  r       record;
  step    interval;
  n       integer;
  applied integer := 0;
begin
  if not public.is_writer() then
    return 0;
  end if;
  for r in
    select * from public.reservations
     where topup_cents is not null
       and topup_start is not null
       and public.can_manage_account(account_id)
     for update
  loop
    step := case r.topup_unit
              when 'week' then interval '1 week'
              when 'year' then interval '1 year'
              else interval '1 month'
            end;
    n := 0;
    while (r.topup_start + (r.topup_count + n) * step)::date <= current_date
          and n < 1000 loop
      n := n + 1;
    end loop;
    continue when n = 0;
    update public.reservations
       set amount_cents = case
             when r.target_cents is null then r.amount_cents + n * r.topup_cents
             else least(r.amount_cents + n * r.topup_cents,
                        greatest(r.target_cents, r.amount_cents))
           end,
           topup_count = r.topup_count + n
     where id = r.id;
    applied := applied + n;
  end loop;
  return applied;
end;
$$;
revoke all on function public.apply_reservation_topups() from public;
grant execute on function public.apply_reservation_topups() to authenticated;

-- Reservierung einlösen: legt die Ausgabe an und verringert/entfernt die
-- Reservierung in EINER Transaktion (sonst würde der Betrag bei einem Fehler
-- zwischen den Schritten doppelt abgezogen). Rechte wie beim Aufrufer.
--   p_keep_rest: Restbetrag weiter reservieren (sonst wird er freigegeben).
--   p_due_on:    Fälligkeit, die danach gelten soll (null = keine).
-- Wiederkehrende Rücklagen werden nie gelöscht, nur verringert.
create or replace function public.redeem_reservation(
  p_id          uuid,
  p_amount      bigint,
  p_occurred_on date,
  p_title       text,
  p_category_id uuid,
  p_note        text,
  p_keep_rest   boolean,
  p_due_on      date
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  r     public.reservations;
  tx_id uuid;
  rest  bigint;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;
  select * into r from public.reservations where id = p_id for update;
  if not found then
    raise exception 'reservation not found';
  end if;

  insert into public.transactions
    (account_id, type, amount_cents, occurred_on, category_id, title, note)
  values
    (r.account_id, 'expense', p_amount, coalesce(p_occurred_on, current_date),
     p_category_id, coalesce(p_title, ''), coalesce(p_note, ''))
  returning id into tx_id;

  rest := greatest(r.amount_cents - p_amount, 0);
  if r.topup_cents is null and (rest = 0 or not coalesce(p_keep_rest, false)) then
    delete from public.reservations where id = p_id;
  else
    update public.reservations
       set amount_cents = case when coalesce(p_keep_rest, false) then rest else 0 end,
           due_on = p_due_on
     where id = p_id;
  end if;
  return tx_id;
end;
$$;
revoke all on function public.redeem_reservation(uuid, bigint, date, text, uuid, text, boolean, date) from public;
grant execute on function public.redeem_reservation(uuid, bigint, date, text, uuid, text, boolean, date) to authenticated;

-- Realtime, damit Änderungen ohne Neuladen greifen.
do $$
begin
  begin
    alter publication supabase_realtime add table public.reservations;
  exception when duplicate_object then null;
  end;
end $$;
