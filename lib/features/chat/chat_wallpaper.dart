import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Latar percakapan, seperti "Wallpaper chat" di WhatsApp. Pilihan disimpan di HP ini, per percakapan.
class ChatWallpaper {
  ChatWallpaper._();

  static const names = ['Bawaan', 'Malam', 'Laut', 'Hutan', 'Senja', 'Ungu', 'Grafit'];

  // Dua warna gradasi (atas, bawah) per pilihan. Indeks 0 = latar bawaan aplikasi.
  static const _colors = <List<Color>>[
    [],
    [Color(0xFF0B1020), Color(0xFF1B2440)],
    [Color(0xFF0E3B53), Color(0xFF0A6C7A)],
    [Color(0xFF12352A), Color(0xFF2E5E3E)],
    [Color(0xFF5B2A3C), Color(0xFFC0714F)],
    [Color(0xFF2A1F4F), Color(0xFF6B4FA0)],
    [Color(0xFF1C1C1E), Color(0xFF3A3A3C)],
  ];

  static String _key(String thread) => 'chat_wallpaper_$thread';

  static Future<int> load(String thread) async {
    try {
      final v = (await SharedPreferences.getInstance()).getInt(_key(thread)) ?? 0;
      return v < 0 || v >= names.length ? 0 : v;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> save(String thread, int i) async {
    try {
      await (await SharedPreferences.getInstance()).setInt(_key(thread), i);
    } catch (_) {}
  }

  /// Null = latar bawaan.
  static Gradient? gradient(int i) => i <= 0 || i >= _colors.length
      ? null
      : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _colors[i]);
}
