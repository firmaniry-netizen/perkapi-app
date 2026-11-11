import 'package:flutter/material.dart';

/// Dulu menampilkan model timbangan 3D yang berputar. Dibuang supaya halaman berisi konten saja, seperti di iOS.
/// Kelas dipertahankan agar pemanggil tidak berubah; kini tidak menggambar apa pun.
class Scale3D extends StatelessWidget {
  const Scale3D({super.key, this.height = 280});
  final double height;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
