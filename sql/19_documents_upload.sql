-- Izinkan semua anggota yang boleh MELIHAT dokumen untuk MENAMBAH dokumen sendiri.
-- Mengubah/menghapus dokumen orang lain tetap hanya untuk manage_document (policy lama tidak diubah).
-- Aman dijalankan ulang. Jalankan di Supabase SQL Editor.
drop policy if exists dc_insert_member on public.documents;
create policy dc_insert_member on public.documents for insert to authenticated
  with check (has_permission('view_document') and uploaded_by = current_member_id());

drop policy if exists perkapi_docs_member_upload on storage.objects;
create policy perkapi_docs_member_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'documents' and has_permission('view_document')
              and (storage.foldername(name))[1] = auth.uid()::text);
