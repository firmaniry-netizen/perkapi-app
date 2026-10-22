import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache baca (read-only) untuk modul NON-sensitif saja (lihat ModuleDef.offlineCache):
/// Buku Saku, Pengumuman, Event, dan catatan milik sendiri.
/// Data perkara, debitur, kreditur, dokumen, anggota, dan pengaduan TIDAK PERNAH disimpan di perangkat.
/// Cache dihapus saat logout. Penulisan data tetap memerlukan koneksi internet.
class OfflineCache {
  OfflineCache._();

  /// true bila daftar yang sedang tampil berasal dari cache.
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  static const _prefix = 'perkapi_cache:';

  static Future<void> save(String key, List<Map<String, dynamic>> rows) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('$_prefix$key', jsonEncode(rows));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>?> load(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('$_prefix$key');
      if (s == null) return null;
      final v = jsonDecode(s);
      if (v is! List) return null;
      return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    offline.value = false;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }
}
