-- =====================================================================
-- Money-Manager · 0006_receipts.sql · Belege/Fotos je Buchung
-- =====================================================================
-- Pfad zum Beleg (in Supabase Storage) an der Buchung + privater Bucket
-- "receipts" mit Zugriff für angemeldete Mitglieder.
-- =====================================================================

alter table public.transactions add column if not exists receipt_path text;

-- Privater Storage-Bucket für Belege
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

-- Zugriff: jedes angemeldete Mitglied darf Belege lesen/hochladen/löschen.
drop policy if exists receipts_select on storage.objects;
create policy receipts_select on storage.objects
  for select to authenticated using (bucket_id = 'receipts');

drop policy if exists receipts_insert on storage.objects;
create policy receipts_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'receipts');

drop policy if exists receipts_update on storage.objects;
create policy receipts_update on storage.objects
  for update to authenticated using (bucket_id = 'receipts');

drop policy if exists receipts_delete on storage.objects;
create policy receipts_delete on storage.objects
  for delete to authenticated using (bucket_id = 'receipts');
