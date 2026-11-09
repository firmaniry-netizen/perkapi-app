# Tantangan & solusi

[← Kembali ke ringkasan](README.md)

| Tantangan | Solusi |
| --- | --- |
| Membangun aplikasi iOS tanpa Mac | Codemagic (Mac di cloud) dengan workflow terpisah untuk cek build, simulator, sideload, dan TestFlight |
| Status pesan seperti WhatsApp | Kolom `last_delivered_at` dan `last_read_at` per peserta, diperbarui lewat RPC dan disiarkan dengan Realtime |
| Panggilan saat aplikasi tertutup | Android: pesan data FCM berprioritas tinggi untuk layar dering; iOS: butuh APNs dari akun Apple Developer |
| Dering tidak terdengar saat iPhone senyap | Konteks audio panggilan masuk diatur agar mengabaikan sakelar senyap, ditambah getar berkala |
| Tampilan "terlalu AI" | Ikon 3D diganti ikon CupertinoIcons dan foto asli kegiatan, palet warna sistem iOS, desain Liquid Glass |
| Kartu anggota sesuai desain cetak | Latar diambil dari desain vektor resmi, data anggota ditempatkan dengan koordinat relatif agar pas di semua ukuran layar |
| Perubahan API paket (`flutter_callkit_incoming` 3.x) | Kode disesuaikan dengan API baru: event bertipe, `CallKitParams`, teks tombol di `AndroidParams` |
