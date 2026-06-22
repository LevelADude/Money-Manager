-- =====================================================================
-- Money-Manager · 0026_receipts_privacy.sql
-- =====================================================================
-- 1) Belege (Storage-Bucket "receipts") pro Eigentuemer absichern. Bisher
--    (0006) durfte jede:r Angemeldete ALLE Belege lesen/listen. Das passt
--    nicht mehr zum Pro-Besitzer-Modell ab 0018/0019. Belegpfade haben die
--    Form "<uid>/<zeitstempel>.<ext>" -> Zugriff jetzt: eigener Ordner ODER
--    wer die verknuepfte Buchung sehen/verwalten darf (Freigabe/Mitglied).
-- 2) Ungenutzte View account_balances entfernen (Salden werden in der App
--    clientseitig berechnet, vgl. lib/shared/balances.dart).
-- =====================================================================

-- Lesen: eigener Ordner ODER sichtbare verknuepfte Buchung.
drop policy if exists receipts_select on storage.objects;
create policy receipts_select on storage.objects for select to authenticated
  using (
    bucket_id = 'receipts' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (
        select 1 from public.transactions t
        where t.receipt_path = storage.objects.name
          and public.can_view_account(t.account_id)
      )
    )
  );

-- Hochladen: nur in den eigenen Ordner.
drop policy if exists receipts_insert on storage.objects;
create policy receipts_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Aktualisieren (upsert): nur eigener Ordner.
drop policy if exists receipts_update on storage.objects;
create policy receipts_update on storage.objects for update to authenticated
  using (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'receipts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Loeschen: eigener Ordner ODER Admin (Archiv-Purge/Wartung) ODER wer die
-- verknuepfte Buchung verwalten darf.
drop policy if exists receipts_delete on storage.objects;
create policy receipts_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'receipts' and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
      or exists (
        select 1 from public.transactions t
        where t.receipt_path = storage.objects.name
          and public.can_manage_account(t.account_id)
      )
    )
  );

-- Ungenutzte View entfernen.
drop view if exists public.account_balances;
