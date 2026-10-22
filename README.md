# PERKAPI
Platform Digital Organisasi Kurator, Kepailitan & PKPU (Flutter + Supabase)

> PENTING: kode ini ditulis tanpa Flutter SDK dan tanpa akses ke database Anda, jadi BELUM dikompilasi
> dan BELUM diuji. Jalankan `flutter analyze` dan kirim error yang muncul agar bisa diperbaiki.
> Flutter yang dibutuhkan: stable 3.27 atau lebih baru.

## Isi
Auth (email/nomor anggota, lupa password, logout semua perangkat, kunci biometrik), RBAC (role + permission,
dicek di UI dan di database lewat RLS), dashboard, bottom navigation + FAB (Android) / sidebar (layar lebar & web),
Buku Saku Saya (CRUD, tag, pin, favorit, arsip, kategori, pencarian) dan Buku Saku Organisasi, Informasi,
Anggota, Kartu Anggota + QR (token acak), Check-in GPS, Perkara, Debitur, Kreditur, Dokumen (bucket privat + signed URL),
Pengaduan (nomor tiket otomatis), Event, Forum, Tugas, Notifikasi, Pencarian global, AI PERKAPI (Edge Function),
Audit Log, mode terang/gelap.

## Langkah pemasangan
1. Database (Supabase SQL Editor, berurutan): `sql/00_check_existing_schema.sql` (cek), `sql/01_resolve_login_email.sql`
   (opsional, login nomor anggota; sesuaikan kolom), `02_additive_columns`, `03_rbac_functions`, `04_rls_policies`,
   `05_triggers_storage` (lalu `08_registration_approval` bila memakai pendaftaran). Baca `docs/SCHEMA_ASSUMPTIONS.md` dulu. Cadangkan database sebelum menjalankan.
2. Flutter:
   ```
   flutter create . --project-name perkapi --platforms=android,web
   cp env.example.json env.json      # isi SUPABASE_URL dan SUPABASE_ANON_KEY (bukan service_role)
   flutter pub get
   flutter analyze
   flutter test
   flutter run --dart-define-from-file=env.json
   ```
3. Android (setelah `flutter create`):
   - `android/app/src/main/AndroidManifest.xml`: tambahkan di dalam `<manifest>`:
     `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>`,
     `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>`,
     `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`, `<uses-permission android:name="android.permission.INTERNET"/>`.
   - `MainActivity` harus `FlutterFragmentActivity` (syarat local_auth).
   - `android/app/build.gradle`: `minSdk` 23 atau lebih.
4. AI: `supabase functions deploy ai-perkapi` lalu `supabase secrets set ANTHROPIC_API_KEY=...`
   (opsional `AI_MODEL`). Key tidak pernah masuk aplikasi.
5. Build: `flutter build apk --release --dart-define-from-file=env.json` dan `flutter build web --dart-define-from-file=env.json`.

## Web Admin
Aplikasi yang sama; pada layar >= 900 px tampil sidebar dengan semua modul sesuai permission.

## Fitur tambahan (tahap 10)
Jalankan `sql/06_features.sql` (atau `perkapi_features.sql`) setelah skrip database utama. Berisi:
- **Peringatan Anggota (Member Alert)**: pengurus mengirim peringatan (Info/Peringatan/Penting) ke semua anggota, satu cabang,
  satu role, atau satu anggota, dengan masa berlaku. Peringatan otomatis dari sistem: keanggotaan akan/sudah berakhir, status tidak aktif,
  tugas lewat deadline/segera jatuh tempo, pengingat catatan, agenda 24 jam, pengaduan menunggu tanggapan. Tampil sebagai banner dan
  lencana di dashboard, halaman `/alerts`, dan juga masuk ke Notifikasi. Permission baru: `manage_alert`.
- Balasan pengaduan (percakapan) + notifikasi ke pelapor, komentar & like forum, RSVP event, checklist tugas,
  berbagi catatan + notifikasi, lampiran (catatan/pengaduan/event), foto profil, verifikasi kartu anggota (tempel isi QR).

## Fitur tambahan (tahap 11)
Jalankan `sql/07_document_versions.sql` (atau `perkapi_features2.sql`). Deploy fungsi AI dokumen:
`supabase functions deploy ai-summarize-document` (memakai secret `ANTHROPIC_API_KEY` yang sama).
- **Versi dokumen**: riwayat versi + upload versi baru (file lama otomatis tersimpan lewat trigger).
- **Ringkasan dokumen oleh AI**: PDF/JPG/PNG maks 10 MB; mengikuti hak akses (RLS).
- **Kalender**: event, tugas saya, dan deadline perkara dalam tampilan bulanan (`/calendar`).
- **Editor teks kaya (Markdown)**: Buku Saku, catatan, pengumuman; toolbar + pratinjau.
- **Pemindai kamera QR** untuk verifikasi kartu anggota (paket `mobile_scanner`).
- **Cache offline (baca saja)** untuk Buku Saku, pengumuman, event, catatan sendiri. Data sensitif (perkara, debitur,
  kreditur, dokumen, anggota, pengaduan) TIDAK disimpan di perangkat. Cache dihapus saat logout.
- **PIN aplikasi 6 digit** (hash ber-salt di secure storage, 5x salah = otomatis keluar akun) dan
  **login OTP email** (Supabase email template harus memuat `{{ .Token }}`).

## Pendaftaran (register) + persetujuan admin utama
Jalankan `sql/08_registration_approval.sql` (setelah 03 dan 04). Alur:
1. Calon anggota membuka **Daftar** di halaman login (nama, email, HP, cabang opsional, password).
2. Trigger database membuat baris `members` berstatus `pending` (tanpa role). Admin utama (SUPER_ADMIN) mendapat notifikasi.
3. Akun `pending`/`rejected` tidak bisa masuk: login langsung ditolak dengan pesan, dan database memblokir semua data lewat
   policy RLS RESTRICTIVE `perkapi_require_approved` (termasuk Storage).
4. Admin utama membuka menu **Pendaftaran** (`/registrations`), lalu **Setujui** (pilih role, nomor anggota opsional) atau **Tolak** (alasan opsional).
   Hanya admin utama yang bisa: RPC `review_registration` memeriksa `is_super()` dan trigger `members_guard_approval`
   mencegah pengguna mengubah status persetujuannya sendiri. Role SUPER_ADMIN tidak bisa diberikan lewat alur ini.
- Anggota lama otomatis berstatus `approved` (default kolom), jadi tidak terkunci.
- Pengaturan Supabase: Authentication > Providers > Email, "Allow new users to sign up" harus aktif. Disarankan aktifkan
  "Confirm email" dan CAPTCHA, dan atur panjang password minimum 8.
- Jika muncul "Database error saving new user": tabel `members` Anda punya kolom wajib (NOT NULL) selain yang diisi trigger;
  sesuaikan `handle_new_user()` di skrip 08.
- Bila menambah tabel baru kelak, jalankan ulang bagian 7 skrip 08 agar tabel itu ikut dipagari.
- Pendaftar yang emailnya sudah ada di `members` (dibuat admin tanpa akun) tidak otomatis ditautkan; admin perlu menggabungkannya manual.

## Foto profil anggota
Jalankan `sql/09_member_avatars.sql`. Foto disimpan di bucket privat `avatars` (JPG/PNG, maks 2 MB; dibatasi juga di sisi server)
dan ditampilkan lewat URL bertanda tangan 1 jam yang di-cache di memori.
- Tampil di: daftar Anggota, detail Anggota, Kartu Anggota, Verifikasi QR (petugas bisa mencocokkan wajah), Dashboard, Profil, dan sidebar web.
  Jika belum ada foto atau gagal dimuat, tampil inisial nama.
- Setiap anggota mengubah/menghapus fotonya sendiri di **Profil** (ikon kamera).
- Pengelola anggota (izin `manage_member`) bisa mengubah/menghapus foto anggota mana pun dari **Anggota > pilih anggota**.
- Foto belum bisa diunggah saat mendaftar (pendaftar belum punya sesi login); unggah setelah disetujui.
- Foto di Forum, Tugas, dan Pengaduan belum ditampilkan (modul itu belum menampilkan avatar penulis).

## Belum dikerjakan (jujur)
- Push notification FCM: butuh proyek Firebase milik Anda (google-services.json + service account) dan konfigurasi Gradle.
- Pengingat lokal di perangkat (flutter_local_notifications): butuh konfigurasi Android native; belum aman dikerjakan tanpa kompilasi.
  Sementara itu pengingat ditampilkan sebagai Peringatan Anggota di dalam aplikasi.
- Sinkronisasi tulis offline (antrean perubahan). Saat offline hanya bisa membaca cache.
- OTP sebagai faktor kedua (MFA) dan fitur "ingat perangkat".
- Pembatasan percobaan login dan backup (atur di Supabase) serta audit keamanan independen sebelum produksi.

## Urutan SQL (Supabase SQL Editor)
Skrip di `sql/` bersifat ADITIF: mengasumsikan tabel dasar (members, cases, personal_notes, roles, dst.)
sudah ada dari `perkapi_complete.sql` (tidak termasuk di folder ini). Urutan: 00 (cek) -> 01 -> 02 -> 03 -> 04 -> 05
-> 06 -> 07 -> 08 -> 09 -> 10. Setelah itu jalankan `11_diagnose_database.sql` (read-only): hasilnya hanya daftar
masalah (tabel/kolom/fungsi/bucket hilang, RLS, akun tanpa data anggota), atau satu baris "SEMUA OK".

## Tahap 12: desain baru, notifikasi langsung, AI, GPS admin
1. `sql/12_gps_tracking.sql` (setelah 03, 04, 08). Jalankan `11_diagnose_database.sql` sesudahnya.
2. `flutter pub get` (menambah flutter_map dan latlong2; peta memakai tile OpenStreetMap, cukup untuk pemakaian ringan).
3. **AI**: `supabase functions deploy ai-perkapi`, `supabase functions deploy ai-summarize-document`,
   `supabase secrets set ANTHROPIC_API_KEY=...`. Jika gagal, pesan di halaman AI menyebut penyebabnya (belum deploy / key salah).
4. **Notifikasi langsung** (saat aplikasi terbuka): banner realtime dari tabel `notifications`, peringatan penting, dan
   ringkasan belum dibaca saat aplikasi dibuka. Butuh `alter publication supabase_realtime` (sudah ada di skrip 12).
   Notifikasi saat aplikasi TERTUTUP tetap butuh Firebase/FCM (belum dikerjakan).
5. **GPS**: anggota membuka menu *Keamanan & SOS*, menyetujui berbagi lokasi, atau menekan SOS. Admin utama membuka
   *Pelacakan GPS*, menekan **Lacak** pada anggota. Lokasi hanya terkirim saat aplikasi anggota terbuka. Hak baca hanya SUPER_ADMIN
   (atau izin `view_location`), ditegakkan di database. Mencabut izin menghapus data lokasi; riwayat dihapus setelah 7 hari.
6. **Logo & animasi**: logo vektor `PerkapiMark` (tergambar saat splash), latar aurora `AuroraBackground`, banner meluncur.

## Ikon aplikasi baru
File `assets_new/app_icon.png` dan `assets_new/app_icon_foreground.png` (1024 px). Pasang dengan paket flutter_launcher_icons:
tambahkan di `pubspec.yaml` (dev_dependencies: `flutter_launcher_icons: ^0.14.1`) lalu
```
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets_new/app_icon.png"
  adaptive_icon_background: "#0F2B5B"
  adaptive_icon_foreground: "assets_new/app_icon_foreground.png"
  web:
    generate: true
    image_path: "assets_new/app_icon.png"
```
lalu jalankan `dart run flutter_launcher_icons`.

## Tahap 13: push saat aplikasi tertutup (Firebase FCM)
1. Buat proyek di console.firebase.google.com, tambahkan aplikasi Android (package name sama dengan `applicationId` di android/app/build.gradle).
2. `dart pub global activate flutterfire_cli`, lalu di folder proyek: `flutterfire configure` (menimpa lib/firebase_options.dart).
3. `flutter pub get`
4. Jalankan `sql/13_push_tokens.sql` di Supabase.
5. Firebase Console > Project settings > Service accounts > Generate new private key (JSON). JANGAN dibagikan atau di-commit.
   PowerShell: `supabase secrets set FCM_SERVICE_ACCOUNT="$(Get-Content key.json -Raw)"`
   `supabase secrets set PUSH_WEBHOOK_SECRET=string_acak_panjang_anda`
6. `supabase functions deploy send-push --no-verify-jwt`
7. Supabase Dashboard > Database > Webhooks > Create: tabel `notifications`, event Insert, tipe Supabase Edge Functions,
   fungsi `send-push`, tambahkan HTTP header `x-webhook-secret` berisi nilai yang sama dengan PUSH_WEBHOOK_SECRET.
8. Salin AndroidManifest.xml (izin POST_NOTIFICATIONS) ke android/app/src/main/, lalu build ulang APK.

## Tahap 14: pelacakan latar, geofence, "Saya aman", pengumuman massal, pengingat, laporan
1. Jalankan `sql/14_geofence_broadcast_reminders_reports.sql` (setelah 12 dan 13).
2. Pengingat otomatis memakai pg_cron: Dashboard > Integrations > Cron > Enable, lalu jalankan ulang skrip 14 agar jadwal 15 menit terpasang.
3. `flutter pub get` (menambah share_plus dan path_provider), salin AndroidManifest.xml terbaru (izin layanan latar), build ulang APK.
4. Pelacakan latar: aktif setelah anggota membuka aplikasi dan admin menekan Lacak (atau anggota menekan SOS). Notifikasi tetap tampil selama dilacak.
5. Menu baru (admin utama): Area (Geofence), Pengumuman Massal, Laporan & Ekspor.

## Tahap 15-16
- `sql/15_fix_personal_notes_recursion.sql`: memperbaiki error 42P17 pada Buku Saku (jalankan sekali).
- `sql/16_member_number_auto.sql`: nomor anggota otomatis `PRK-TAHUN-NNNN` saat anggota disetujui atau ditambahkan admin.

## Tahap 17: chat, tanda tangan elektronik, pencarian isi PDF, ekspor PDF
1. Jalankan `sql/17_chat_signature_search.sql`.
2. Deploy fungsi indeks PDF: `supabase functions deploy index-document` (JWT tetap aktif, jangan pakai --no-verify-jwt).
3. `flutter pub get` (menambah paket `pdf`), lalu bangun APK baru.
4. Dokumen > ikon kaca pembesar di atas: indeks PDF lama. PDF baru terindeks otomatis saat diunggah. PDF hasil pindai (gambar) tidak punya teks dan tidak bisa dicari tanpa OCR.

## Desain baru + Galeri Dokumentasi (tahap 12)
Jalankan `sql/18_gallery.sql` (bucket privat `gallery` + tabel `gallery_photos` + RLS). Menu: Beranda > Galeri atau Semua menu > Galeri Dokumentasi (`/gallery`).
Pilih banyak foto sekaligus, beri album dan keterangan, lihat grid, geser dan zoom di penampil layar penuh, hapus milik sendiri.
Layar dalam kini memakai `ScreenHero` (kepala dongker bergradasi) dan warna pembeda modul (`AppColors.forKey`).

### Desain tahap 12b
`lib/core/widgets/illustrations.dart`: ilustrasi digambar dengan kode (timbangan keadilan, tumpukan foto, kartu kosong, pola titik). Komponen baru di `ui_kit.dart`: `SolidTile`, `StatCard`, `ScreenHero` (diperbarui). Beranda punya banner Galeri dan kartu statistik berwarna.

### Animasi tahap 12c
Splash: garis merah menyapu, titik halus, lalu lingkaran melebar menutup layar sebelum masuk (`_RevealPainter`). Transisi halaman: geser + skala + fade (`FadeThroughBuilder`). Ubin menu: `PopIn` (membal berjenjang) + `Hero` ikon ke kepala layar tujuan (`heroTag: 'tile:<id>'`). Semua mati saat Reduce Motion aktif.

### Halus + warna tahap 12d
`lib/core/widgets/smooth_overlays.dart`: `showSmoothSheet` dan `showSmoothDialog` menggantikan showModalBottomSheet/showDialog di semua layar (kurva mendarat lembut, scrim dongker, tutup lebih singkat). Tombol utama bergradasi merah dengan cahaya, pil navigasi aktif bergradasi dongker, kartu dengan bayangan dua lapis, gulir memantul, Pressable dengan pegas saat dilepas.

### Tahap 12e
Kepala layar `ScreenHero` kini juga di Dokumen, Laporan, dan Kalender. Login memakai pola titik + timbangan samar. Profil memakai ikon pintasan berwarna, pola titik, timbangan, dan strip merah.

### Tahap 12f
`sql/19_documents_upload.sql`: anggota yang boleh melihat dokumen kini boleh menambah dokumen sendiri (ubah/hapus milik orang lain tetap manage_document). Tombol Upload tampil untuk semua yang bisa membuka Dokumen. Galeri menampilkan penyebab gagal unggah, dan tombol "Tambah foto" di Beranda langsung membuka pemilih foto.

### Tahap 12g
Pemilihan foto/dokumen tidak lagi memuat isi file ke memori (`withData` hanya di web); unggah lewat path (`lib/core/utils/upload_helper.dart`). Thumbnail galeri didekode kecil (`cacheWidth`) agar hemat RAM.

## Berita (dashboard + hapus khusus admin)
Jalankan `sql/21_news_admin.sql` (setelah `18_gallery.sql` dan `20_gallery_news.sql`). Isinya:
- Fungsi `is_admin()` = role `SUPER_ADMIN`, `ADMIN_PUSAT`, atau `ADMIN_CABANG` (ubah daftar kodenya di skrip bila perlu).
- **Hapus berita/foto hanya admin**: policy RLS `gp_delete` pada `gallery_photos` dan policy Storage bucket `gallery`
  memakai `is_admin()`. Anggota biasa tidak bisa menghapus walau memanggil API langsung. Tombol hapus di aplikasi
  (dashboard, daftar berita, halaman berita) hanya tampil untuk admin.
- Semua anggota yang sudah disetujui dapat membaca berita; tabel berita ikut dipagari `perkapi_require_approved`.
- **Dashboard**: bagian "Berita terbaru" (carousel 5 berita terbaru) tampil untuk semua pengguna; ketuk untuk membuka berita.

Gambar opsional untuk berita: lihat `docs/GAMBAR.md`.

## Berita (tahap 12): hapus hanya admin + tampil di dashboard semua pengguna
Jalankan `sql/20_gallery_news.sql` lalu **`sql/21_news_admin.sql`** (aman dijalankan ulang).
- Semua akun yang sudah disetujui dapat MEMBACA berita dan melihat carousel **Berita terbaru** di dashboard; semua anggota boleh menulis berita.
- **Hapus berita/foto hanya admin** (SUPER_ADMIN, ADMIN_PUSAT, ADMIN_CABANG; ubah daftar di fungsi `is_admin()` bila perlu). Ditegakkan di database
  (RLS tabel `gallery_photos` + policy Storage bucket `gallery`), jadi akun non-admin tetap ditolak walau tombolnya dipaksa muncul.
- Gambar tambahan (opsional) lihat `docs/GAMBAR.md`.

## Pendaftaran AHU (tahap 13)
Jalankan `sql/22_ahu_registration.sql` (setelah 03, 06, 08, 09; aman diulang). Menu **Pendaftaran AHU** (`/ahu`, juga di Profil).
- Anggota mengisi nomor Surat Bukti Pendaftaran Kurator dan Pengurus, tanggal terbit, dan masa berlaku (opsional).
- Lencana **Terverifikasi AHU** hanya bisa diberikan pengelola anggota (`manage_member`) atau admin utama, setelah mencocokkan dengan dokumen/situs AHU.
  Anggota yang mengubah datanya sendiri otomatis kehilangan verifikasi. Ditegakkan oleh trigger database.
- Tampil di Kartu Anggota dan layar Verifikasi QR. Peringatan otomatis 60 hari sebelum masa berlaku AHU berakhir (lewat `my_alerts`).
- Tombol **Buka AHU Online** membuka https://ahu.go.id. Aplikasi TIDAK mengambil data dari server AHU (tidak ada API publik yang dikonfirmasi).

## Ruang Kerja Perkara (tahap 14)
Jalankan `sql/23_case_workbench.sql` (setelah 02, 04, 06, 22; aman diulang). Buka **Perkara**, pilih satu perkara, lalu ikon **Ruang kerja** di kanan atas.
- **Linimasa**: tahapan perkara dengan tanggal, status (selesai/terlambat/H-n), progres, dan template Kepailitan/PKPU. Pengingat otomatis (3 hari sebelum dan terlambat) masuk ke
  Peringatan untuk kurator yang ditugaskan di perkara itu. Tanggal otomatis HANYA untuk batas UU 37/2004 yang saya yakini (pengumuman putusan pailit 5 hari, sidang PKPU Sementara maks. 45 hari,
  PKPU Tetap maks. 270 hari). Cocokkan dengan undang-undang dan penetapan Hakim Pengawas; tahap lain diisi manual.
- **Tagihan**: per kreditur (jenis Konkuren/Separatis/Preferen, jumlah diajukan, status Diajukan/Diakui/Bersyarat/Dibantah, jumlah diakui), rekap total, ekspor Excel (CSV) dan PDF, impor dari daftar kreditur perkara.
- **Surat**: Undangan Rapat Kreditur, Pemberitahuan dan Permintaan Pengajuan Tagihan, Berita Acara Rapat Kreditur. Terisi dari data perkara, debitur, kreditur, dan kurator (termasuk No. SBP AHU bila ada),
  hasil PDF dibagikan lewat lembar bagikan. Teks adalah draf umum: periksa dan sesuaikan sebelum dikirim. Surat per kreditur dibuat satu halaman per kreditur.
- Hak akses mengikuti perkara: baca = `view_case` atau kurator yang ditugaskan; ubah = `manage_case` (ditegakkan RLS).

## Tahap 15: redesain "Tegas & Tenang 2.0"
Lihat `docs/REDESIGN.md` (ringkasan) dan `docs/design-dna.json` (token). Token jarak/radius/tipografi ada di
`lib/core/constants/app_tokens.dart`. Ubin ikon (`SolidTile`, `IconBadge`) dan `StatCard` kini lembut, bukan gradasi pekat.
`lib/core/widgets/glass_widgets.dart` dihapus karena tidak dipakai di mana pun.

## Tahap 16: pemeriksaan notifikasi & pengingat
Halaman **Pengaturan > Notifikasi & pengingat** (`lib/features/settings/notification_status_page.dart`) memeriksa Firebase, izin, pendaftaran HP,
dan jadwal pengingat, serta punya tombol notifikasi uji. Jalankan `sql/24_notification_health.sql` SETELAH `sql/14` (pengingat berbasis tanggal kini hanya
dikirim 07.00-20.00 WIB). Panduan lengkap Firebase: `docs/NOTIFIKASI.md`.

## Fitur yang dihapus (tahap 15)
Dihapus dari kode dan database: **Perkara** (ruang kerja, linimasa, tagihan, surat), **Debitur**, **Kreditur**, **Dokumen** (versi, tanda tangan, ringkasan/indeks AI), **Pengaduan**, **Tugas**, dan **Absensi**.
Bagian README di atas yang membahas fitur-fitur itu kini hanya riwayat. Yang tetap ada: Buku Saku, Anggota, Kartu Anggota + QR, Event, Forum, Kalender (event saja), Chat, Berita, Keamanan & SOS, Pelacakan/Geofence, Notifikasi, Pengumuman Massal, Laporan & Ekspor (anggota dan event), Profil Organisasi, dan menu **Profesi** (Pendaftaran, Perpanjangan, Format Laporan AHU, Data AHU Saya).

Database (urutan dan peringatan ada di komentar masing-masing skrip):
1. Buat backup, lalu jalankan `sql/25a_check_before_remove.sql` (hanya membaca) dan baca hasilnya.
2. Pasang APK versi baru ke semua pengguna.
3. Jalankan `sql/25_remove_unused_features.sql` (permanen; satu transaksi, bila gagal tidak ada yang berubah).
4. Kosongkan lalu hapus bucket Storage `documents`, `case-documents`, `complaint-attachments`, dan `signatures` lewat Dashboard, serta hapus dua Edge Function: `supabase functions delete index-document` dan `supabase functions delete ai-summarize-document`.

Skrip lama `02`, `04`, `05`, `06`, `07`, `14`, `17`, `19`, `22`, `23`, `24` tetap ada sebagai riwayat. Jangan dijalankan ulang SETELAH skrip 25 pada database yang sama, karena akan membuat tabel/fungsi yang sudah dihapus muncul lagi.
