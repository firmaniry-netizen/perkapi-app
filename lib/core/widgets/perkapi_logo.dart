import 'package:flutter/material.dart';

import 'perkapi_mark.dart';

/// Logo PERKAPI. Sekarang vektor ([PerkapiMark]) sehingga tajam di semua ukuran
/// dan tidak lagi bergantung pada file gambar. Parameter [onDark] dipertahankan agar
/// pemanggil lama tidak rusak (lencana dongker terlihat jelas di kedua mode).
class PerkapiLogo extends StatelessWidget {
  const PerkapiLogo({super.key, this.size = 96, this.onDark = false, this.animate = false});

  final double size;
  final bool onDark;
  final bool animate;

  @override
  Widget build(BuildContext context) => PerkapiMark(size: size, animate: animate);
}
