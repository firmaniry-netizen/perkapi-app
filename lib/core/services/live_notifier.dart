import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/alerts/alert_service.dart';
import 'access_service.dart';
import 'supabase_service.dart';

class LiveNotice {
  LiveNotice({required this.id, required this.title, required this.body, this.type = 'info', this.link});
  final String id, title, body, type;
  final String? link;
  bool get urgent => type == 'sos';
}

/// Notifikasi langsung SELAMA APLIKASI TERBUKA:
///  1. Realtime: setiap baris baru di tabel `notifications` milik pengguna langsung tampil sebagai banner.
///  2. Peringatan penting (urgent/warning) dari AlertService tampil sekali.
///  3. Saat aplikasi dibuka: ringkasan "N notifikasi belum dibaca".
/// Catatan: ini BUKAN push saat aplikasi tertutup (itu butuh Firebase/FCM).
class LiveNotifier {
  LiveNotifier._();
  static final LiveNotifier instance = LiveNotifier._();

  final ValueNotifier<LiveNotice?> current = ValueNotifier(null);
  final Set<String> _shown = {};
  RealtimeChannel? _channel;
  Timer? _hide;
  String? _memberId;

  void start() {
    final id = Access.instance.memberId;
    if (id == null || (_memberId == id && _channel != null)) return;
    stop();
    _memberId = id;
    _channel = SupabaseService.client
        .channel('live-notif-$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'member_id', value: id),
          callback: (payload) {
            final r = payload.newRecord;
            final nid = '${r['id']}';
            if (!_shown.add('n$nid')) return;
            show(LiveNotice(
              id: nid,
              title: '${r['title'] ?? 'Notifikasi baru'}',
              body: '${r['body'] ?? ''}',
              type: '${r['type'] ?? 'info'}',
              link: r['link'] as String?,
            ));
          },
        )
        .subscribe();
    AlertService.instance.addListener(_onAlerts);
    Future<void>.delayed(const Duration(milliseconds: 1600), _unreadSummary);
  }

  void stop() {
    _channel?.unsubscribe();
    _channel = null;
    _memberId = null;
    _hide?.cancel();
    AlertService.instance.removeListener(_onAlerts);
    _shown.clear();
    current.value = null;
  }

  void _onAlerts() {
    for (final a in AlertService.instance.highlights) {
      if (_shown.add('a${a.id}')) {
        show(LiveNotice(
            id: a.id, title: a.title, body: a.body, type: a.severity == 'urgent' ? 'urgent' : 'warning', link: '/alerts'));
        return;
      }
    }
  }

  Future<void> _unreadSummary() async {
    final id = _memberId;
    if (id == null || current.value != null) return;
    try {
      final rows = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('member_id', id)
          .eq('is_read', false);
      final n = (rows as List).length;
      if (n > 0 && current.value == null) {
        show(LiveNotice(
            id: 'summary',
            title: 'Anda punya $n notifikasi belum dibaca',
            body: 'Ketuk untuk membukanya.',
            link: '/notifications'));
      }
    } catch (_) {}
  }

  void show(LiveNotice n) {
    current.value = n;
    if (n.urgent) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    SystemSound.play(SystemSoundType.alert);
    _hide?.cancel();
    _hide = Timer(Duration(seconds: n.urgent ? 12 : 6), dismiss);
  }

  void dismiss() {
    _hide?.cancel();
    current.value = null;
  }
}
