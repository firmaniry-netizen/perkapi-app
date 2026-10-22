import 'package:flutter/material.dart';

class AlertStyle {
  const AlertStyle(this.color, this.background, this.icon, this.label);
  final Color color, background;
  final IconData icon;
  final String label;

  static AlertStyle of(String severity) {
    switch (severity) {
      case 'urgent':
        return const AlertStyle(
            Color(0xFFC62828), Color(0xFFFFEBEE), Icons.error_outline, 'Penting');
      case 'warning':
        return const AlertStyle(
            Color(0xFFEF6C00), Color(0xFFFFF3E0), Icons.warning_amber_rounded, 'Peringatan');
      default:
        return const AlertStyle(
            Color(0xFF2456B8), Color(0xFFE3EAF8), Icons.info_outline, 'Info');
    }
  }
}

String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}
