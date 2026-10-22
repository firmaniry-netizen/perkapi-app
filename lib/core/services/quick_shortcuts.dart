import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

/// Pintasan di ikon aplikasi (tekan lama ikon): Agenda, Kartu anggota, Scan QR. Diabaikan di web.
class QuickShortcuts {
  QuickShortcuts._();

  static const _routes = {
    'agenda': '/calendar',
    'member_card': '/member-card',
    'scan': '/verify-member',
  };

  static void init(GoRouter router) {
    if (kIsWeb) return;
    try {
      const qa = QuickActions();
      qa.initialize((type) {
        final loc = _routes[type];
        if (loc != null) router.go(loc); // jika belum login, redirect router mengarahkan ke login
      });
      qa
          .setShortcutItems(const [
            ShortcutItem(type: 'agenda', localizedTitle: 'Agenda'),
            ShortcutItem(type: 'member_card', localizedTitle: 'Kartu anggota'),
            ShortcutItem(type: 'scan', localizedTitle: 'Scan QR'),
          ])
          .catchError((_) {});
    } catch (_) {}
  }
}
