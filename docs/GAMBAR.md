# Foto untuk PERKAPI (opsional, tapi sangat mengangkat tampilan)

Aplikasi tetap berjalan tanpa foto: setiap slot otomatis tidak menggambar apa pun bila filenya belum ada,
jadi tampilan kembali ke dongker polos (tanpa kotak rusak). Simpan file di `images/` dengan nama PERSIS di bawah,
lalu `flutter pub get` dan jalankan ulang. Tidak perlu mengubah `pubspec.yaml` (folder sudah terdaftar).

| Nama file | Dipakai di | Gambaran foto yang cocok | Ukuran |
|---|---|---|---|
| `hero_login.jpg` | Latar halaman masuk (portrait) | Palu hakim + buku hukum di meja kayu gelap, atau rak buku hukum; area gelap/biru, tanpa wajah jelas | 1080 x 1920, < 350 KB |
| `hero_member.jpg` | Kartu anggota di dashboard + kepala layar dalam (landscape) | Dokumen/kontrak dan pena di meja, atau gedung pengadilan; nuansa biru/gelap, ruang kosong di kiri | 1200 x 700, < 250 KB |
| `news_placeholder.jpg` | Sampul berita tanpa foto | Meja kerja hukum, tumpukan berkas, timbangan keadilan | 1200 x 800, < 300 KB |

## Foto sudah ditaruh tapi tidak muncul? Periksa berurutan
1. Folder harus bernama `images/` dan sejajar dengan `lib/` dan `pubspec.yaml` (BUKAN di dalam `lib/`).
2. Nama file persis (huruf kecil semua): `hero_login.jpg`, `hero_member.jpg`, `news_placeholder.jpg`. Di Windows, aktifkan
   "File name extensions" agar tidak terjadi `hero_login.jpg.jpg`.
3. Aset hanya dimuat saat build. Hentikan aplikasi lalu jalankan: `flutter clean`, `flutter pub get`, `flutter run`.
   Hot reload dan hot restart TIDAK cukup. Untuk web, lakukan hard refresh (Ctrl+Shift+R).
4. Lihat konsol saat mode debug. Bila foto gagal dimuat akan tercetak: `PhotoBackdrop: gagal memuat "images/...". ...`.

## Cara memilih (penting)
- **Lisensi.** Pexels: "Free to use", tanpa kewajiban atribusi (tetap baca halaman lisensinya). Unsplash: pilih hanya foto
  TANPA label **Unsplash+** (itu berbayar). Burst (Shopify): lisensinya "Some Rights Reserved", baca syaratnya dulu.
  Jangan memakai foto toko/produk atau hasil pencarian gambar umum: lisensinya tidak jelas.
- **Hindari wajah yang jelas.** Foto orang nyata di aplikasi organisasi bisa bermasalah (hak potret) dan terasa generik.
  Pilih benda: palu, buku, berkas, gedung.
- **Gelap/biru lebih baik.** Aplikasi menaruh bayangan dongker 74-80% di atas foto agar teks putih tetap terbaca;
  foto yang sudah gelap tidak jadi "lumpur".
- Kompres di squoosh.app (JPG, kualitas 70-75).

## Tempat mencari
- Pexels: https://www.pexels.com/search/gavel/ , https://www.pexels.com/search/legal%20documents/ ,
  https://www.pexels.com/search/law%20library/
- Unsplash: https://unsplash.com/s/photos/gavel , https://unsplash.com/s/photos/law ,
  https://unsplash.com/s/photos/legislation (ingat: lewati yang berlabel Unsplash+)
- Contoh kandidat di Pexels: "Judge signing documents at desk with focus on gavel" (https://www.pexels.com/photo/6077447/).
  Saya hanya melihat judulnya, bukan fotonya langsung, jadi lihat dulu apakah ada wajah/warna yang cocok.

## Perilaku di aplikasi
Foto muncul halus (fade + zoom-out 1,07 -> 1 selama 0,9 detik, satu kali) dan langsung tampil bila Reduce Motion aktif.
Kodenya: `lib/core/widgets/photo_backdrop.dart`; nama file ada di `lib/core/constants/app_assets.dart`.
