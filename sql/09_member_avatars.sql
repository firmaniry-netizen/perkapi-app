-- 09: Foto profil untuk semua anggota. ADITIF & AMAN: tanpa tabel baru; hanya policy storage baru,
-- batas bucket, dan pembaruan fungsi verify_member_qr. Jalankan setelah 05 (dan 08 bila dipakai).
-- Kolom members.avatar_path sudah dibuat di 02_additive_columns.sql.

-- 1) Batas bucket avatars di sisi server: maks 2 MB, hanya JPG/PNG (tidak bergantung pada aplikasi).
update storage.buckets
   set file_size_limit = 2097152,
       allowed_mime_types = array['image/jpeg','image/png']
 where id = 'avatars';

-- 2) Pengelola anggota (manage_member) boleh mengunggah/mengganti/menghapus foto anggota mana pun
--    di folder `members/<member_id>/`. Foto milik sendiri tetap di `<auth.uid>/` (policy dari 05).
--    Policy digabung OR dengan policy lama; pagar `perkapi_*_require_approved` dari 08 tetap berlaku.
drop policy if exists perkapi_avatar_admin_insert on storage.objects;
drop policy if exists perkapi_avatar_admin_update on storage.objects;
drop policy if exists perkapi_avatar_admin_delete on storage.objects;

create policy perkapi_avatar_admin_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'members' and has_permission('manage_member'));
create policy perkapi_avatar_admin_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'members' and has_permission('manage_member'));
create policy perkapi_avatar_admin_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = 'members' and has_permission('manage_member'));

-- 3) Verifikasi QR ikut mengembalikan foto agar petugas bisa mencocokkan wajah dengan kartu.
create or replace function verify_member_qr(p_token uuid) returns jsonb
language sql stable security definer set search_path = public as
$$ select case when has_permission('manage_member') then
     (select jsonb_build_object('full_name', full_name, 'member_number', member_number, 'status', status,
                                'valid_until', valid_until, 'avatar_path', avatar_path)
      from members where qr_token = p_token) else null end $$;

grant execute on function verify_member_qr(uuid) to authenticated;
