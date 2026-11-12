import 'package:flutter/material.dart';

import '../../core/constants/phosphor_icons.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Pengaturan percakapan milik saya sendiri: bisukan, arsipkan, sematkan di daftar chat (SQL 49).
class ChatPrefs {
  ChatPrefs._();

  /// Null pada [archived] / [pinned] = tidak diubah. Bisu hanya diubah bila [setMute] true.
  static Future<void> set(String thread, {bool? archived, bool? pinned, bool setMute = false, DateTime? mutedUntil}) async {
    await SupabaseService.client.rpc('chat_set_thread_prefs', params: {
      'p_thread': thread,
      'p_archived': archived,
      'p_pinned': pinned,
      'p_set_mute': setMute,
      'p_muted_until': mutedUntil?.toUtc().toIso8601String(),
    });
  }

  static bool isMuted(Object? v) {
    final t = v is DateTime ? v : DateTime.tryParse('${v ?? ''}');
    return t != null && t.isAfter(DateTime.now());
  }

  /// Pilihan durasi bisu seperti WhatsApp. Mengembalikan waktu berakhir, atau null bila dibatalkan.
  static Future<DateTime?> pickMute(BuildContext context) {
    return showSmoothSheet<DateTime>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Bisukan notifikasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Pesan tetap masuk, tetapi tidak ada notifikasi.', textAlign: TextAlign.center),
          ),
          for (final (label, dur) in const [('8 jam', Duration(hours: 8)), ('1 minggu', Duration(days: 7))])
            ListTile(
              leading: const Icon(Ph.bellSlash),
              title: Text(label),
              onTap: () => Navigator.pop(ctx, DateTime.now().add(dur)),
            ),
          ListTile(
            leading: const Icon(Ph.bellSlash),
            title: const Text('Selalu'),
            onTap: () => Navigator.pop(ctx, DateTime(2100)),
          ),
        ]),
      ),
    );
  }
}
