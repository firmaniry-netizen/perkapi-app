import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();
  // Tampilan terang (putih + dongker + merah segel) menjadi bawaan; mode gelap dan "ikuti sistem" ada di Pengaturan.
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);
}
