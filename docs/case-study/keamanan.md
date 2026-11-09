# Keamanan

[← Kembali ke ringkasan](README.md)

## Database
- **Row Level Security** aktif di setiap tabel: anggota hanya bisa membaca dan mengubah data yang menjadi haknya.
- Fungsi sensitif memakai `security definer` dengan pengecekan keanggotaan (misalnya `chat_is_member`), dan hak eksekusinya dicabut dari pengguna anonim.
- Hak akses berbasis peran (RBAC): role dan permission dicek di UI dan di database.

## Kunci rahasia
- Aplikasi hanya memegang kunci publik Supabase (anon/publishable key).
- Kunci service role, service account Firebase, dan kunci AI hanya tersimpan sebagai secret Edge Functions.
- Webhook notifikasi diverifikasi dengan header rahasia sebelum diproses.

## Aplikasi
- Kunci aplikasi dengan PIN dan biometrik.
- QR kartu anggota memakai token acak, bukan data pribadi.
- Dokumen disimpan di bucket privat dan dibuka lewat signed URL.

## Website
- File kerja, skrip pembangun, dan file sensitif tidak ikut di-deploy.
- Header keamanan dan pembatasan akses lewat `.htaccess`.
