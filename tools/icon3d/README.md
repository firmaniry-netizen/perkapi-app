# Ikon 3D PERKAPI

Sumber gambar `images/3d/*.png` di aplikasi. Setiap ikon adalah model three.js sederhana (lihat `scene.js`) dengan warna merek
(dongker, emas, merah marun), dirender ke PNG transparan 1024 px lalu dikecilkan ke 384 px.

Cara merender ulang / menambah ikon:
1. Salin three.js r160 ke folder ini sebagai `three/` (berisi `build/three.module.js` dan `examples/jsm/environments/RoomEnvironment.js`).
2. Sajikan folder ini (mis. `python -m http.server 8090`), buka `index.html`, lalu di konsol peramban:
   `const url = await __r("lonceng"); open(url)` — simpan gambarnya.
3. Potong & kecilkan ke 384 px, simpan ke `images/3d/<nama>.png`, lalu daftarkan ikon Flutter-nya di `lib/core/constants/art_3d.dart`.
