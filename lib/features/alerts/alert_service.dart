import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';

class AlertItem {
  AlertItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    required this.isRead,
  });

  final String id, kind, title, body, severity;
  final DateTime? createdAt;
  bool isRead;

  bool get isSystem => kind == 'system';

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: '${j['id']}',
        kind: '${j['kind'] ?? 'manual'}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        severity: '${j['severity'] ?? 'info'}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
        isRead: j['is_read'] == true,
      );
}

/// Peringatan anggota (manual dari pengurus + otomatis dari sistem).
/// Di-refresh tiap 60 detik selama aplikasi terbuka.
class AlertService extends ChangeNotifier {
  AlertService._();
  static final AlertService instance = AlertService._();

  List<AlertItem> items = [];
  String? error;
  Timer? _timer;
  final Set<String> _seenSystem = {};

  int get unread => items.where((e) => !e.isRead).length;

  /// Peringatan penting yang belum dibaca (untuk banner di dashboard).
  List<AlertItem> get highlights => items
      .where((e) => !e.isRead && (e.severity == 'urgent' || e.severity == 'warning'))
      .toList();

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (Access.instance.memberId == null) {
      stop();
      items = [];
      _seenSystem.clear();
      notifyListeners();
      return;
    }
    try {
      final res = await SupabaseService.client.rpc('my_alerts');
      if (res is List) {
        items = res
            .map((e) => AlertItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        for (final a in items) {
          if (a.isSystem && _seenSystem.contains(a.id)) a.isRead = true;
        }
        error = null;
      }
    } catch (_) {
      error = 'Gagal memuat peringatan. Pastikan skrip perkapi_features.sql sudah dijalankan.';
    }
    notifyListeners();
  }

  Future<void> markRead(AlertItem a) async {
    if (a.isRead) return;
    a.isRead = true;
    notifyListeners();
    if (a.isSystem) {
      _seenSystem.add(a.id);
      return;
    }
    try {
      await SupabaseService.client.rpc('mark_alert_read', params: {'p_id': a.id});
    } catch (_) {
      // abaikan; akan sinkron pada refresh berikutnya
    }
  }

  Future<void> markAllRead() async {
    for (final a in items) {
      a.isRead = true;
      if (a.isSystem) _seenSystem.add(a.id);
    }
    notifyListeners();
    try {
      await SupabaseService.client.rpc('mark_all_alerts_read');
    } catch (_) {}
  }
}
