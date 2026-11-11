-- Izinkan anggota menghapus notifikasinya sendiri (fitur "Hapus" dan "Hapus semua" di tab Notifikasi).
-- Sebelumnya tabel notifications hanya punya policy SELECT dan UPDATE untuk pemiliknya (lihat 04_rls_policies.sql),
-- sehingga perintah hapus dari aplikasi diam-diam tidak menghapus apa pun.
-- Aman dijalankan ulang. Jalankan di Supabase: SQL Editor.
drop policy if exists nt_delete on public.notifications;
create policy nt_delete on public.notifications
  for delete
  using (member_id = current_member_id());
