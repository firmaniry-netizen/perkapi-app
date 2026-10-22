# Asumsi skema database

Saya tidak dapat melihat database Supabase Anda, sehingga nama kolom di aplikasi
(`lib/shared/models/modules.dart`) adalah ASUMSI. Cara memastikan:

1. Jalankan `sql/00_check_existing_schema.sql` dan bandingkan dengan kolom di bawah.
2. Jika nama kolom Anda berbeda (mis. `name` bukan `full_name`), ubah di `modules.dart`
   ATAU biarkan `sql/02_additive_columns.sql` menambah kolom baru (hanya `add column if not exists`).
3. Jalankan SQL berurutan: 01 (opsional) -> 02 -> 03 -> 04 -> 05. Baca semua pesan NOTICE "SKIP".
   Tabel dengan RLS aktif tanpa policy = tidak ada akses, jadi periksa bagian SKIP di skrip 04.

Kolom penting per tabel: lihat `sql/02_additive_columns.sql` (daftar lengkap).
Penghubung akun: `members.user_id` harus diisi dengan `auth.users.id` tiap anggota.
Role: `roles.code` (SUPER_ADMIN, ADMIN_PUSAT, ADMIN_CABANG, PENGURUS, KURATOR, PENGURUS_PKPU, STAFF, ANGGOTA, VIEWER)
diisi otomatis dari `roles.name` jika kosong.

Satu-satunya tabel baru: `role_permissions` (permission fleksibel per role). Tidak ada tabel asset.

Anggota pertama (bootstrap): buat user di Supabase Auth, isi `members.user_id`, beri role SUPER_ADMIN
lewat `member_roles` (jalankan lewat SQL Editor sebagai owner; RLS tidak berlaku di sana).
