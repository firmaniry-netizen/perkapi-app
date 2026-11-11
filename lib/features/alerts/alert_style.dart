import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import '../../core/constants/app_colors.dart';

class AlertStyle {
  const AlertStyle(this.color, this.background, this.icon, this.label);
  final Color color, background;
  final IconData icon;
  final String label;

  static AlertStyle of(String severity) {
    switch (severity) {
      case 'urgent':
        return const AlertStyle(
            AppColors.red, Color(0xFFFFEBEE), Ph.warningCircle, 'Penting');
      case 'warning':
        return const AlertStyle(
            AppColors.amber, Color(0xFFFFF3E0), Ph.warning, 'Peringatan');
      default:
        return const AlertStyle(
            AppColors.navyAction, Color(0xFFE3EAF8), Ph.info, 'Info');
    }
  }
}

String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}
