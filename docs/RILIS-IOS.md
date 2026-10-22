# Merilis PERKAPI ke iPhone (tanpa Mac)

Aplikasi iOS hanya bisa dikompilasi di macOS. Di sini kompilasi dilakukan oleh **Codemagic** (Mac di cloud)
memakai `codemagic.yaml` di akar proyek. Semua langkah di bawah bisa dikerjakan dari Windows lewat peramban.

## Sekali saja

1. **Apple Developer Program** (USD 99/tahun) — https://developer.apple.com/programs/
2. **App ID** — developer.apple.com → Certificates, IDs & Profiles → Identifiers → `+` → App IDs
   - Bundle ID (Explicit): `id.or.perkapi.app`
   - Centang **Push Notifications**.
3. **Kunci APNs untuk notifikasi** — Keys → `+` → centang *Apple Push Notifications service (APNs)* → unduh berkas `.p8`
   (hanya bisa diunduh sekali; simpan baik-baik). Catat **Key ID** dan **Team ID**.
4. **Firebase** — console.firebase.google.com → proyek `perkapi-112` → Project settings → Cloud Messaging →
   Apple app configuration → unggah `.p8` + Key ID + Team ID.
5. **App Store Connect** — https://appstoreconnect.apple.com → Apps → `+` → New App
   (platform iOS, bundle `id.or.perkapi.app`). Setelah dibuat, buka *App Information*, salin **Apple ID** (angka)
   ke `APP_STORE_APPLE_ID` di `codemagic.yaml`.
6. **Kunci API App Store Connect** — Users and Access → Integrations → App Store Connect API → `+`
   (akses: App Manager). Unduh `.p8`, catat Issuer ID & Key ID.
7. **Codemagic** — https://codemagic.io → masuk dengan GitHub → tambahkan repositori aplikasi.
   - Team settings → Integrations → *Developer Portal* → masukkan kunci API dari langkah 6,
     beri nama persis `PERKAPI App Store Connect`.
   - Aplikasi → Environment variables → grup **firebase** (centang *Secure*), isi dua variabel berikut.
     Berkas konfigurasi Firebase sengaja TIDAK disimpan di GitHub; Codemagic membuatnya ulang dari variabel ini.
     Jalankan di PowerShell (Windows), hasilnya langsung tersalin — tempel sebagai nilai variabel:
     ```powershell
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\perkapi\lib\firebase_options.dart")) | Set-Clipboard   # -> FIREBASE_OPTIONS_DART
     [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\perkapi\android\app\google-services.json")) | Set-Clipboard   # -> GOOGLE_SERVICES_JSON
     ```
   - Team settings → Code signing identities → iOS certificates → *Generate certificate* (Distribution),
     lalu iOS provisioning profiles → *Fetch profiles* (App Store, `id.or.perkapi.app`).

## Setiap rilis

1. Naikkan `version:` di `pubspec.yaml` (mis. `0.2.0+1`), lalu push ke GitHub.
2. Codemagic → *Start new build* → workflow **iOS → TestFlight**.
3. ±20–30 menit kemudian build muncul di TestFlight. Pasang lewat aplikasi TestFlight di iPhone untuk menguji
   (termasuk notifikasi — simulator tidak bisa menerima push).
4. Bila sudah baik: App Store Connect → isi deskripsi, tangkapan layar (iPhone 6,9" & 6,5"; iPad bila iPad didukung),
   kebijakan privasi (URL halaman privasi situs), lalu *Submit for Review*.

## Catatan

- Izin di `ios/Runner/Info.plist` sudah ada: kamera, foto, lokasi saat dipakai, Face ID, notifikasi latar.
- `ios/Runner/Runner.entitlements` berisi hak Push Notifications (`aps-environment`). Untuk build App Store,
  nilai "development" otomatis diganti "production" saat penandatanganan.
- Aplikasi mendukung iPad (`TARGETED_DEVICE_FAMILY = 1,2`), jadi App Store meminta tangkapan layar iPad juga.
  Bila ingin khusus iPhone, ubah menjadi `1`.
- Android: workflow **Android → APK** menghasilkan APK untuk dipasang langsung. Untuk Google Play,
  `applicationId` masih `com.example.perkapi` — Play Store menolak nama `com.example`. Ganti dulu (mis. `id.or.perkapi.app`)
  dan daftarkan ulang aplikasi Android di Firebase (unduh `google-services.json` baru) sebelum rilis ke Play Store.

## Apa yang tidak ada di GitHub (sengaja)

| Berkas | Alasan | Disimpan di |
|---|---|---|
| `env.json` | konfigurasi lokal | komputer Anda |
| `lib/firebase_options.dart`, `android/app/google-services.json` | kunci klien Firebase | komputer Anda + variabel rahasia Codemagic |
| `*.p8`, `*.p12`, `*.jks`, `key.properties` | kunci penandatanganan & APNs | pengelola kata sandi / Codemagic |
| `supabase/.temp/` | alamat database proyek | komputer Anda |

Kunci rahasia server (Supabase `service_role`, akun layanan FCM, kunci AI) tidak pernah ada di kode — semuanya di
Supabase → Edge Functions → Secrets. Kunci *publishable* Supabase di `lib/core/constants/env.dart` memang dirancang
publik (juga tampil di situs) dan dilindungi aturan RLS database.
