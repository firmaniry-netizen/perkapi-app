import 'package:flutter/material.dart';

/// Dulu menambah cahaya radial berwarna aksen di belakang bagian atas halaman. Cahaya itu dibuang supaya latar
/// halaman polos seperti aplikasi iOS; kelas dipertahankan agar halaman yang memakainya tidak perlu diubah.
class PageGlow extends StatelessWidget {
  const PageGlow({super.key, required this.accent, required this.child, this.height = 340});
  final Color accent;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) => child;
}
