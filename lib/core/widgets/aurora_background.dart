import 'package:flutter/material.dart';

/// Latar hitam polos untuk layar gelap (kunci, masuk, sambutan). Dulu dongker dengan cahaya aurora yang bergerak;
/// dibuat hitam supaya senada dengan mode gelap iOS. Nama kelas dipertahankan agar pemanggil tidak berubah.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: Colors.black, child: SizedBox.expand(child: child));
}
