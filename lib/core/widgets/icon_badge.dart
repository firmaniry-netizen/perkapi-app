import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'ui_kit.dart';

/// Kotak ikon bergradasi (sama dengan [SolidTile]). Dipakai di daftar, kalender, dokumen, absensi, pengaturan.
/// Tanpa [color] dipakai biru aksi (kontras baik dengan ikon putih di mode terang maupun gelap).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 48});
  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SolidTile(icon: icon, color: color ?? AppColors.navyAction, size: size, radius: size * 0.375);
}
