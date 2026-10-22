# Notifikasi & pengingat: agar sampai ke HP saat aplikasi tertutup

## Yang sudah ada di kode
- Server mengirim pengingat otomatis tiap 15 menit (`run_reminders`, pg_cron) dan menaruhnya di tabel `notifications`.
- Fungsi `send-push` meneruskan setiap baris `notifications` baru ke HP lewat Firebase (FCM).
- Aplikasi mendaftarkan token HP setelah login dan membuka halaman yang dituju saat notifikasi diketuk.
- Halaman baru **Pengaturan > Notifikasi & pengingat** memeriksa semua mata rantai di bawah dan punya tombol kirim notifikasi uji.

Yang BELUM aktif di proyek Anda: `lib/firebase_options.dart` masih file sementara, jadi Firebase belum dikonfigurasi.
Itu harus dikerjakan di akun Firebase Anda sendiri (langkah 2).

## Urutan (Windows PowerShell)
**1. Database (Supabase > SQL Editor), berurutan:** `13_push_tokens.sql`, `14_geofence_broadcast_reminders_reports.sql`, lalu `24_notification_health.sql`.
- Aktifkan Cron dulu: Dashboard > Integrations > Cron > Enable. Setelah itu jalankan ulang `14`, lalu **`24` lagi**.
- PENTING: `24` harus selalu dijalankan SETELAH `14`. Menjalankan ulang `14` mengembalikan fungsi pengingat ke versi lama (terkirim tengah malam).

**2. Firebase**
1. console.firebase.google.com > buat proyek > tambah aplikasi Android. Package name harus SAMA dengan `applicationId` di `android/app/build.gradle` (atau `.kts`).
2. Di folder proyek:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Pilih platform Android. Ini menimpa `lib/firebase_options.dart` dan membuat `android/app/google-services.json`.
   Biasanya plugin `google-services` ikut ditambahkan ke Gradle otomatis. Jika build gagal dengan pesan soal google-services,
   tambahkan manual sesuai https://firebase.google.com/docs/flutter/setup
3. Firebase Console > Project settings > Service accounts > Generate new private key (file JSON). Jangan dibagikan atau di-commit.

**3. Kunci dan fungsi di Supabase** (login dulu dengan `supabase login`, dan `supabase link` ke proyek Anda):
```
supabase secrets set FCM_SERVICE_ACCOUNT="$(Get-Content key.json -Raw)"
supabase secrets set PUSH_WEBHOOK_SECRET=string_acak_panjang_anda
supabase functions deploy send-push --no-verify-jwt
```
Lalu Supabase Dashboard > Database > Webhooks > Create: tabel `notifications`, event **Insert**, tipe Supabase Edge Functions,
fungsi `send-push`, tambahkan HTTP header `x-webhook-secret` dengan nilai yang SAMA dengan `PUSH_WEBHOOK_SECRET`.

**4. Jalankan ulang aplikasi di HP** (bukan hot reload):
```
flutter clean
flutter pub get
flutter run --dart-define-from-file=env.json
```
Izinkan notifikasi saat diminta (Android 13 ke atas).

**5. Uji:** Pengaturan > Notifikasi & pengingat. Keempat baris harus hijau. Tekan **Kirim notifikasi uji**, tekan Home, tunggu beberapa detik.

## Jika ada yang merah atau tidak muncul
| Gejala | Penyebab umum |
|---|---|
| "Firebase di aplikasi" merah | `flutterfire configure` belum dijalankan, atau aplikasi belum dibuild ulang |
| "Izin notifikasi" merah | Aktifkan di Pengaturan HP > Aplikasi > PERKAPI > Notifikasi |
| "HP ini terdaftar" merah | `13_push_tokens.sql` belum dijalankan; keluar lalu masuk lagi |
| "Pengingat otomatis" merah | Cron belum di-Enable; jalankan ulang `14` lalu `24` |
| Semua hijau tapi uji tidak muncul | Cek Supabase > Edge Functions > send-push > Logs. Biasanya header `x-webhook-secret` tidak sama, atau `FCM_SERVICE_ACCOUNT` salah, atau webhook belum dibuat |
| Muncul di sebagian HP saja | Penghemat baterai (Xiaomi, Oppo, Vivo, Samsung) mematikan aplikasi di latar. Izinkan "Mulai otomatis" / "Tanpa pembatasan baterai" untuk PERKAPI. Aplikasi yang di-"Paksa berhenti" tidak menerima push |
| Notifikasi masuk tapi tidak muncul pop-up di atas layar | Normal: Android memakai saluran bawaan FCM (bunyi, tanpa pop-up). Pop-up butuh saluran khusus (kode native) |

## Belum dibuat (bisa menyusul)
- Pengingat lokal terjadwal di HP (bekerja tanpa internet). Butuh `flutter_local_notifications` dan konfigurasi Android native yang harus diuji lewat kompilasi.
- Pilihan per pengguna (jenis pengingat, jam tenang sendiri). Jam kirim sekarang tetap 07.00-20.00 WIB untuk semua.
- Push untuk pengingat catatan (sekarang hanya muncul sebagai Peringatan di dalam aplikasi). Pengingat tugas dan perkara sudah dihapus bersama fiturnya (lihat README, tahap 15).
