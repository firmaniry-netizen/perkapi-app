# Redesain "Tegas & Tenang 2.0"

Identitas tetap: dongker `#0F2B5B` + merah segel `#C8202F`. Yang berubah adalah permukaan, tipografi, dan konsistensi.
Nama kelas dan parameter publik TIDAK diubah, jadi semua layar lama tetap kompatibel.

## Prinsip
1. Satu titik fokus per layar (di dashboard: kartu anggota). Elemen lain tenang.
2. Warna aksen dipakai lembut (latar 12%, ikon berwarna) dan bermakna; merah hanya untuk aksi utama dan status mendesak.
3. Tipografi satu skala (`AppType`), jarak kelipatan 4/8 (`AppSpace`), radius dari satu sumber (`AppRadius`).
4. Bayangan dua lapis bertinta dongker (`softShadow`), tidak pernah abu murni.
5. Status tidak hanya bergantung warna (titik + teks).

## File yang diubah
| File | Perubahan |
|---|---|
| `core/constants/app_tokens.dart` (baru) | Token jarak, radius, skala tipografi, bayangan |
| `core/constants/app_colors.dart` | Aksen modul lebih selaras; latar/garis sedikit lebih terang; helper `soft()` dan `onSoft()` |
| `app/theme.dart` | Skala tipografi nyata (perbaikan bug bobot di helper `serif`), tombol/input/kartu/chip seragam |
| `core/widgets/ui_kit.dart` | `AppCard`, `PrimaryButton`, `AppIconButton` (kotak membulat), `SectionHeader`, `SolidTile` (lembut), `StatCard` (permukaan bersih), `ScreenHero` (ikon kaca, aksen merah pendek) |
| `features/dashboard/dashboard_page.dart` | Impor ganda dihapus; kartu AI tenang; warna statistik per jenis; kartu anggota lebih tegas |
| `features/shell/app_shell.dart` | Pil navigasi aktif lembut, FAB bercincin, layar kunci lebih jelas |
| `shared/widgets/state_widgets.dart` | Ikon status kotak membulat, `StatusChip` dengan titik penanda |
| `features/auth/login_page.dart` | Pesan galat dalam kotak, jarak 8-pt, teks lebih jelas |
| `features/modules/module_list_view.dart` | Banner offline ikut tema (aman di mode gelap), padding kartu 16 |

## Putaran 2
| File | Perubahan |
|---|---|
| `core/widgets/icon_badge.dart` | Gradasi diganti latar lembut (seragam dengan `SolidTile`) |
| `core/widgets/glass_widgets.dart` | DIHAPUS (kode mati, tidak ada yang mengimpor; juga menggandakan `SectionHeader`/`QuickTile`/`Wordmark`) |
| `features/profile/profile_page.dart` | Aksen merah pendek, radius token, tombol Keluar bernada galat |
| `features/calendar/calendar_page.dart` | Hari terpilih solid (tanpa gradasi + bayangan) |
| `features/ahu/ahu_page.dart`, `features/cases/case_claims_tab.dart` | Radius kartu ringkasan diseragamkan (28) |
| `docs/design-dna.json`, `README.md` | Disesuaikan dengan token baru |

## Putaran 3 (efek + foto)
| File | Perubahan |
|---|---|
| `core/widgets/photo_backdrop.dart` (baru) | Foto latar dengan bayangan dongker, fade + zoom-out sekali; tak menggambar apa pun bila file tidak ada; patuh Reduce Motion |
| `core/constants/app_assets.dart` | Slot `heroLogin` dan `heroMember` |
| `core/widgets/motion.dart` | `tapHaptic()` |
| `core/widgets/ui_kit.dart` | Haptik di `PrimaryButton`, `AppIconButton`, `QuickTile`; `ScreenHero` memakai foto |
| `features/shell/app_shell.dart` | Haptik di navigasi bawah dan FAB |
| `features/auth/login_page.dart`, `features/dashboard/dashboard_page.dart` | Foto latar; header dashboard kaca buram saat digulir |
| `docs/GAMBAR.md` | Panduan lengkap: 3 slot foto, lisensi, cara memilih, tempat mencari |

## Putaran 4 (halaman dalam lebih kaya + perbaikan foto)
Penyebab foto tidak muncul: kode dan `pubspec.yaml` mencari `assets/images/`, padahal folder gambar proyek ada di `images/`.
Sekarang `pubspec.yaml` dan `AppAssets` memakai `images/`.

| File | Perubahan |
|---|---|
| `pubspec.yaml`, `core/constants/app_assets.dart` | Jalur aset diperbaiki ke `images/` |
| `core/widgets/photo_backdrop.dart` | Pesan galat di konsol (debug) bila foto gagal dimuat |
| `core/constants/app_colors.dart` | `tileGradient()` |
| `core/widgets/ui_kit.dart` | `SolidTile` bergradasi + kilau + bayangan warna; `StatCard` bergradasi + tanda air; `AppCard(wash:)`; `SectionHeader` pil gradasi; `ScreenHero` mengikuti warna modul + cahaya radial; `GradientIconButton` baru |
| `core/widgets/icon_badge.dart` | Memakai `SolidTile` |
| `features/modules/module_list_view.dart` | Kartu bergradasi tipis, chip panah berwarna, tombol Tambah bergradasi |
| `features/modules/module_list_page.dart` | Cahaya radial warna modul di belakang kepala layar |

## Putaran 5 (kepala berwarna di semua layar dalam)
Komponen baru `core/widgets/page_glow.dart`: cahaya radial berwarna aksen di belakang bagian atas halaman, muncul halus 0,8 detik.
Dipasang di `body:` 19 layar. Warna per layar: Perkara/Ruang kerja/Pengaturan/Pendaftaran AHU = biru atau teal, Tugas/Absensi/Area/Verifikasi = teal,
Chat/AI/Pengumuman = ungu, Kalender = oranye, Dokumen/Pencarian = biru langit, Galeri = mawar, Peringatan/Keamanan/Laporan = merah, Persetujuan = amber.
Form modul memakai warna modulnya sendiri (`AppColors.forKey`).

Kepala `ScreenHero` berwarna ditambahkan di: form modul (tambah/ubah data), Absensi, Pengumuman Massal, Keamanan & SOS, Verifikasi Kartu.

## Belum diverifikasi
Kode ini belum dikompilasi (tidak ada Flutter SDK di lingkungan pembuatnya). Jalankan:
```
flutter pub get
flutter analyze
flutter run --dart-define-from-file=env.json
```
lalu cek mode terang DAN gelap, font sistem besar, dan layar sempit (~320 dp).

## Putaran 6 — "Tegas & Tenang 3.0": selaras situs + gerak & 3D yang bermakna
Tujuan: membereskan temuan audit (beranda padat, tombol merah lemah, dua lonceng, form tanpa jam, daftar seragam,
halaman kosong buntu, ukuran huruf acak, beda merek dengan situs, efek menumpuk) lalu menambah gerak/3D di tempat yang tepat.

### Identitas
| File | Perubahan |
|---|---|
| `fonts/InstrumentSerif-*.ttf` (baru, OFL) + `pubspec.yaml` | Huruf aksen situs resmi dibundel (tanpa unduh saat runtime) |
| `core/constants/app_tokens.dart` | `AppType.headline()` (Plus Jakarta Sans 800 rapat, seperti h1–h3 situs), `AppType.accent()` (Instrument Serif miring, kata aksen emas), token gerak `AppMotion` |
| `app/theme.dart` | Judul 800 dengan spasi huruf rapat; sapaan beranda & layar menunggu persetujuan memakai kata aksen miring emas seperti situs |

Catatan: putaran ini sempat memakai Big Shoulders Display (salah baca CSS lama situs). Sudah diganti; berkas `fonts/BigShouldersDisplay-*.ttf` tidak dipakai lagi dan boleh dihapus.
| `core/constants/app_colors.dart` | Emas situs: `gold`, `goldDeep` (4,7:1 di putih), `goldHi`. Oranye & merah muda dilebur ke emas; `success`/`warning` semantik |
| Semua layar | Ukuran huruf di luar skala (9, 10, 10.5, 11.5, 12.5, 13.5, 15.5, 16.5, 17, 21) dibulatkan ke skala; tidak ada lagi teks < 11 |

### Layar & alur
| File | Perubahan |
|---|---|
| `features/dashboard/dashboard_page.dart` | Beranda diringkas: kartu anggota 3D → cari → 8 pintasan (tanpa duplikat navigasi bawah) → agenda (kartu tanggal geser) → berita → informasi. Statistik & kartu AI dihapus. Satu lonceng "Kotak masuk" dengan lencana gabungan |
| `features/dashboard/member_hero_card.dart` (baru) | Kartu anggota 3D: miring ikut HP/jari, paralaks 3 lapis, foil hologram emas-biru, sorot cahaya, pola guilloche, cip emas; masuk dengan "berdiri" sekali |
| `core/widgets/live_tilt.dart` (baru) | Kemiringan 3D hemat baterai: gambar ulang hanya saat bergerak, bisu saat tertutup halaman lain, sensor lepas di latar, netral menyesuaikan cara pegang |
| `features/shell/action_burst.dart` (baru) + `app_shell.dart` | Tombol merah membuka menu "mekar" (gelembung terbang berpegas ke grid, latar blur, tombol berputar jadi ×): Kartu & QR, SOS, Tulis berita, Catatan, Tanya AI, Data AHU + aksi pengurus sesuai hak akses |
| `features/alerts/alerts_page.dart` + `app/router.dart` | Kotak masuk satu pintu: tab Peringatan / Notifikasi / Terkirim (pengelola). `/inbox` baru; `/notifications` & `/alerts` tetap hidup |
| `shared/models/modules.dart` + `module_form_page.dart` | `FieldType.datetime`: tanggal + jam (24 jam, disimpan UTC). Agenda Mulai/Selesai & Pengingat catatan kini berjam. Wajib-isi divalidasi; Selesai tidak boleh sebelum Mulai |
| `features/modules/module_list_view.dart` | Kartu khusus: Agenda (blok tanggal emas, jam, lokasi, Hari ini/Selesai/Di situs), Forum (kategori berwarna, cuplikan, waktu relatif), Notifikasi (belum dibaca tebal + titik). Keadaan kosong per modul + tombol aksi |
| `shared/widgets/state_widgets.dart` | `EmptyState(title, actionLabel, onAction)` + ilustrasi melayang; `fmtValue` menampilkan "21 Okt 2026 • 09.30" (waktu lokal) |
| `core/utils/format_id.dart` (baru) | Format tanggal/jam Indonesia tanpa data locale |
| `features/shell/app_shell.dart` | Sidebar tablet/web dikelompokkan (Organisasi / Profesi / Akun & sistem) dengan garis emas pada menu aktif; layar kunci baru (aurora + cincin bernapas); navigasi bawah tanpa blur terus-menerus (lebih ringan) |
| `features/auth/pending_approval_view.dart` | Layar menunggu persetujuan: aurora, cincin bernapas, garis waktu 3 langkah, tombol periksa dengan status memuat |
| `core/widgets/ui_kit.dart` | `SectionHeader` & `ScreenHero` memakai huruf judul situs; `ScreenHero` tanpa foto/pola titik berulang, ditambah garis emas tipis |

### Sistem gerak (ringkas)
- Umpan balik tekan: skala 0,98, 100 ms turun / 340 ms easeOutBack naik (sudah ada, `Pressable`).
- Masuk konten: fade + naik, 620 ms, Cubic(0.16,1,0.3,1), jenjang 55 ms (`Reveal`).
- Fisik/berpegas: easeOutBack untuk gelembung menu & ubin (`PopIn`, `action_burst`).
- 3D hidup: kartu anggota (LiveTilt), maks. 0,16 rad, interpolasi 0,12/frame, zona mati 0,015.
- Kedalaman gulir: kartu anggota mengecil 6% & meredup 45% dalam 260 px pertama.
- Gerak berulang hanya dua: cincin bernapas (menunggu) dan ilustrasi kosong melayang. Keduanya diam saat "kurangi gerak".

### Wajib dicek setelah menarik kode
```
flutter pub get
flutter analyze
flutter run --dart-define-from-file=env.json
```
Cek: beranda (miringkan HP), tombol merah, Kotak masuk, tambah agenda (pilih jam), mode gelap, font sistem besar, layar ~320 dp, dan tablet (sidebar).

## Putaran 7 — gestur & animasi tata letak (pola Reanimated, versi Flutter)
Reanimated adalah pustaka React Native, jadi tidak bisa dipasang di aplikasi Flutter ini. Yang diambil adalah polanya
(skill reanimated-gestures & reanimated-layout-animations), dibuat dengan alat bawaan Flutter tanpa paket tambahan:

| Pola Reanimated | Padanan di PERKAPI | File |
|---|---|---|
| Konstanta `SPRING` / `withSpring` (bounce 0) | `AppSpring.snap` & `AppSpring.heavy` (pegas teredam kritis, meneruskan kecepatan jari) | `core/widgets/motion_physics.dart` |
| Swipeable row (`Gesture.Pan` + `activeOffsetX`/`failOffsetY`, offset pattern, `runOnJS` di akhir) | `SwipeRow`: geser horizontal saja (daftar tetap bisa digulir), ambang 32% atau kibasan > 900 px/s, getar sekali di ambang, ikon aksi 0,25 → 1, aksi juga tersedia untuk pembaca layar | `core/widgets/swipe_row.dart` |
| `entering` / `exiting` / `layout={LinearTransition}` + `LayoutAnimationConfig skipEntering` | `AnimatedItemsList`: item baru masuk (280 ms), item hilang keluar lebih singkat (180 ms), item lain bergeser halus; isi awal tidak dianimasikan | `core/widgets/animated_items_list.dart` |
| Kibas & pegas dengan kecepatan | Kartu anggota: geser ke samping untuk membalik (mengikuti jari, lepas = pegas ke sisi terdekat / sisi berikutnya bila dikibas) | `features/members/member_card_page.dart` |
| Tarik untuk menutup (pan + snap/dismiss) | Menu aksi cepat: tarik ke bawah untuk menutup, tirai menipis saat ditarik | `features/shell/action_burst.dart` |
| `FadeIn`/`FadeOut` antar keadaan | Daftar modul: memuat → daftar/kosong/galat memudar silang | `features/modules/module_list_view.dart` |
| `layout` transition untuk elemen yang muncul/hilang | Banner peringatan di Beranda: isi di bawahnya bergeser halus, tidak melompat | `features/dashboard/dashboard_page.dart` |

Dipakai di Kotak masuk: geser kartu peringatan ke kanan = tandai dibaca; saringan "Belum dibaca" membuat kartu yang
sudah dibaca keluar dengan animasi dan kartu di bawahnya naik. Semua gerak menjadi instan saat "kurangi gerak" aktif.
