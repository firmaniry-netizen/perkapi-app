import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Status "online" anggota lewat Supabase Realtime Presence.
/// Anggota dianggap online selama aplikasinya terbuka di layar (bukan di latar belakang).
/// Dipasang sekali oleh AppShell; halaman chat cukup membaca [online].
class OnlineService with WidgetsBindingObserver {
  OnlineService._();
  static final instance = OnlineService._();

  /// member_id yang sedang online (tidak termasuk diri sendiri).
  final online = ValueNotifier<Set<String>>(<String>{});

  RealtimeChannel? _ch;
  String? _me;
  bool _tracked = false;

  void start(String? memberId) {
    if (memberId == null || _me == memberId) return;
    stop();
    _me = memberId;
    WidgetsBinding.instance.addObserver(this);
    final ch = SupabaseService.client.channel('perkapi-online');
    _ch = ch;
    ch.onPresenceSync((_) => _sync()).subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) _track(true);
    });
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    final ch = _ch;
    _ch = null;
    _tracked = false;
    _me = null;
    online.value = <String>{};
    if (ch != null) SupabaseService.client.removeChannel(ch);
  }

  bool isOnline(String? memberId) => memberId != null && online.value.contains(memberId);

  Future<void> _track(bool on) async {
    final ch = _ch, me = _me;
    if (ch == null || me == null) return;
    try {
      if (on && !_tracked) {
        await ch.track({'member': me});
        _tracked = true;
      } else if (!on && _tracked) {
        await ch.untrack();
        _tracked = false;
      }
    } catch (_) {}
  }

  void _sync() {
    final ch = _ch;
    if (ch == null) return;
    final ids = <String>{};
    for (final s in ch.presenceState()) {
      for (final p in s.presences) {
        final id = p.payload['member'];
        if (id is String && id != _me) ids.add(id);
      }
    }
    online.value = ids;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _track(state == AppLifecycleState.resumed);
  }
}
