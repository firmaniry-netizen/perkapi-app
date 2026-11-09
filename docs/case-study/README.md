# PERKAPI — Aplikasi Mobile & Website Resmi (Case Study)

Aplikasi resmi **Persatuan Kurator dan Pengurus Indonesia (PERKAPI)** untuk Android dan iOS, beserta website
[perkapi.or.id](https://perkapi.or.id). Dirancang dan dibangun oleh **Riqo Iqbal** sebagai Mobile & Web Developer (2026).

![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)
![Firebase](https://img.shields.io/badge/Firebase-FCM-FFCA28?logo=firebase)
![Codemagic](https://img.shields.io/badge/CI%2FCD-Codemagic-F45E3F)

## Ringkasan

PERKAPI membutuhkan satu aplikasi untuk anggotanya: kartu anggota digital, berita dan agenda organisasi,
peraturan kepailitan, pengelolaan dokumen dan perkara, serta komunikasi antar-anggota. Aplikasi dibangun
dengan Flutter sehingga satu basis kode berjalan di Android dan iOS, dengan backend Supabase.

| Ukuran | Angka |
| --- | --- |
| Baris kode Dart | ±26.500 (129 file) |
| Modul fitur | 31 |
| Rute navigasi | 47 |
| Skrip migrasi SQL | 34 |
| Supabase Edge Functions | 5 |
| Workflow CI/CD Codemagic | 5 |
| Halaman website | 17 |

## Peran saya

- Merancang dan menulis aplikasi Flutter dari awal sampai siap rilis.
- Merancang database PostgreSQL di Supabase beserta aturan keamanan Row Level Security (RLS).
- Menulis Edge Functions (TypeScript/Deno) untuk push notification, AI, dan kredensial panggilan.
- Mendesain UI/UX bergaya iOS "Liquid Glass" (glassmorphism, design tokens, mode gelap, kontras tinggi).
- Menyiapkan build otomatis Android dan iOS di Codemagic, serta mengurus Google Play Console dan Apple Developer Program.
- Membangun dan men-deploy website perkapi.or.id ke Hostinger.

## Dokumentasi

| Dokumen | Isi |
| --- | --- |
| [Fitur](fitur.md) | Fitur per modul |
| [Arsitektur](arsitektur.md) | Diagram sistem, alur chat, notifikasi, dan panggilan |
| [CI/CD](ci-cd.md) | Workflow Codemagic untuk Android dan iOS |
| [Keamanan](keamanan.md) | RLS, pengelolaan kunci rahasia, pengamanan website |
| [Tantangan & solusi](tantangan.md) | Masalah teknis yang diselesaikan |

## Tech stack

- **Mobile:** Flutter, Dart, go_router, ChangeNotifier/ValueNotifier, flutter_webrtc, firebase_messaging, local_auth, qr_flutter, mobile_scanner, audioplayers
- **Backend:** Supabase — PostgreSQL, Auth, Realtime, Storage, RPC, Edge Functions (TypeScript/Deno)
- **Notifikasi:** Firebase Cloud Messaging (Android & iOS lewat APNs)
- **Web:** HTML, CSS, JavaScript, Three.js — di-hosting di Hostinger
- **DevOps:** Git, GitHub, Codemagic, Google Play Console, App Store Connect / TestFlight

## Tangkapan layar

Simpan screenshot di folder [`screenshots/`](screenshots/) dengan nama di bawah, lalu gambar akan tampil di sini.
Pakai data contoh, bukan data anggota asli.

| Beranda | Kartu anggota | Chat |
| --- | --- | --- |
| ![Beranda](screenshots/beranda.png) | ![Kartu anggota](screenshots/kartu-anggota.png) | ![Chat](screenshots/chat.png) |

| Semua menu | Panggilan | Website |
| --- | --- | --- |
| ![Semua menu](screenshots/semua-menu.png) | ![Panggilan](screenshots/panggilan.png) | ![Website](screenshots/website.png) |

## Kontak

Riqo Iqbal · riqoiqbal@gmail.com · [LinkedIn](https://www.linkedin.com/in/riqo-iqbal-6b85373b9)
