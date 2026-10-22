import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../shared/models/modules.dart';
import '../modules/module_list_view.dart';
import '../../core/widgets/animated_items_list.dart';
import '../../core/widgets/swipe_row.dart';
import 'alert_service.dart';
import 'alert_style.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Kotak masuk: SATU tempat untuk Peringatan (dari pengurus/sistem) dan Notifikasi (aktivitas akun),
/// ditambah tab "Terkirim" untuk pengelola peringatan. Dibuka dari satu lonceng di Beranda.
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key, this.initialTab = 0});

  /// 0 = Peringatan, 1 = Notifikasi, 2 = Terkirim (pengelola).
  final int initialTab;
  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  @override
  void initState() {
    super.initState();
    AlertService.instance.refresh();
  }

  Future<void> _compose() async {
    final sent = await context.push<bool>('/alerts/new');
    if (sent == true) {
      AlertService.instance.refresh();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Access.instance.can('manage_alert');
    final inbox = _Inbox(onRefresh: AlertService.instance.refresh);
    final notif = modules['notifications'];
    final tabs = <Widget>[
      ListenableBuilder(
        listenable: AlertService.instance,
        builder: (_, __) => _TabLabel('Peringatan', AlertService.instance.unread),
      ),
      const _TabLabel('Notifikasi', 0),
      if (admin) const _TabLabel('Terkirim', 0),
    ];
    final views = <Widget>[
      inbox,
      if (notif != null) ModuleListView(module: notif, showAdd: false) else const EmptyState(),
      if (admin) const _SentList(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kotak masuk'),
        actions: [
          IconButton(
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all),
            onPressed: AlertService.instance.markAllRead,
          ),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: _compose,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Kirim peringatan'),
            )
          : null,
      body: PageGlow(
        accent: AppColors.red,
        child: DefaultTabController(
          length: tabs.length,
          initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
          child: Column(children: [
            TabBar(tabs: tabs),
            Expanded(child: TabBarView(children: views)),
          ]),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.text, this.count);
  final String text;
  final int count;
  @override
  Widget build(BuildContext context) => Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Badge(label: Text(count > 99 ? '99+' : '$count'), backgroundColor: AppColors.red, textColor: Colors.white),
          ],
        ]),
      );
}

/// Kotak masuk peringatan.
/// - Saringan "Semua / Belum dibaca". Di "Belum dibaca", peringatan yang ditandai dibaca keluar dari daftar
///   dengan animasi, dan kartu di bawahnya naik mengisi tempatnya (AnimatedItemsList).
/// - Geser kartu ke kanan = tandai dibaca (SwipeRow); ketuk = buka rincian.
class _Inbox extends StatefulWidget {
  const _Inbox({required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  bool _unreadOnly = false;

  void _open(BuildContext context, AlertItem a) {
    AlertService.instance.markRead(a);
    final s = AlertStyle.of(a.severity);
    showSmoothSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(s.icon, color: s.color),
              const SizedBox(width: 8),
              Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(a.isSystem ? 'Otomatis' : fmtDateTime(a.createdAt),
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 12),
            Text(a.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (a.body.isNotEmpty) Text(a.body),
          ]),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, AlertItem a) {
    final s = AlertStyle.of(a.severity);
    final scheme = Theme.of(context).colorScheme;
    return SwipeRow(
      startAction: a.isRead
          ? null
          : SwipeAction(
              label: 'Tandai dibaca',
              icon: Icons.done_rounded,
              color: AppColors.emerald,
              onCommit: () => AlertService.instance.markRead(a),
            ),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        color: a.isRead ? null : Color.alphaBlend(s.color.withValues(alpha: 0.10), scheme.surface),
        onTap: () => _open(context, a),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(s.icon, color: s.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: a.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(
                a.body.isEmpty ? (a.isSystem ? 'Otomatis' : fmtDateTime(a.createdAt)) : a.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ]),
          ),
          // titik "belum dibaca" mengecil & memudar saat dibaca (silang-pudar, bukan hilang mendadak)
          AnimatedScale(
            scale: a.isRead ? 0.25 : 1,
            duration: const Duration(milliseconds: 220),
            curve: const Cubic(0.2, 0, 0, 1),
            child: AnimatedOpacity(
              opacity: a.isRead ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(Icons.circle, size: 10, color: s.color),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlertService.instance,
      builder: (context, _) {
        final svc = AlertService.instance;
        if (svc.error != null && svc.items.isEmpty) {
          return ErrorState(message: svc.error!, onRetry: widget.onRefresh);
        }
        if (svc.items.isEmpty) {
          return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'Semua aman',
              message: 'Tidak ada peringatan untuk Anda. Peringatan penting dari pengurus akan muncul di sini.');
        }
        final shown = _unreadOnly ? svc.items.where((e) => !e.isRead).toList() : List.of(svc.items);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              ChoiceChip(label: const Text('Semua'), selected: !_unreadOnly, onSelected: (_) => setState(() => _unreadOnly = false)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Belum dibaca (${svc.unread})'),
                selected: _unreadOnly,
                onSelected: (_) => setState(() => _unreadOnly = true),
              ),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: shown.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                      SizedBox(height: 40),
                      EmptyState(
                          icon: Icons.done_all_rounded,
                          title: 'Semua sudah dibaca',
                          message: 'Tidak ada peringatan baru. Lihat semua peringatan di saringan "Semua".'),
                    ])
                  : AnimatedItemsList<AlertItem>(
                      items: shown,
                      keyOf: (a) => a.id,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      itemBuilder: _card,
                    ),
            ),
          ),
        ]);
      },
    );
  }
}

/// Daftar peringatan yang pernah dikirim (hanya pengelola).
class _SentList extends StatefulWidget {
  const _SentList();
  @override
  State<_SentList> createState() => _SentListState();
}

class _SentListState extends State<_SentList> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.client
          .from('member_alerts')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      _rows = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _error = 'Gagal memuat daftar peringatan terkirim.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle(Map<String, dynamic> r, bool on) async {
    try {
      await SupabaseService.client
          .from('member_alerts')
          .update({'is_active': on}).eq('id', r['id']);
      await _load();
    } catch (_) {
      _snack('Gagal mengubah status peringatan.');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus peringatan?'),
        content: const Text('Peringatan akan hilang dari semua anggota.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.client.from('member_alerts').delete().eq('id', r['id']);
      await _load();
    } catch (_) {
      _snack('Gagal menghapus peringatan.');
    }
  }

  String _target(Map<String, dynamic> r) {
    switch (r['target_type']) {
      case 'branch':
        return 'Cabang tertentu';
      case 'role':
        return 'Role tertentu';
      case 'member':
        return 'Anggota tertentu';
      default:
        return 'Semua anggota';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) return const EmptyState(message: 'Belum ada peringatan terkirim');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _rows[i];
          final s = AlertStyle.of('${r['severity']}');
          final active = r['is_active'] == true;
          return Card(
            child: ListTile(
              leading: Icon(s.icon, color: s.color),
              title: Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${_target(r)} • ${fmtDateTime(DateTime.tryParse('${r['created_at']}')?.toLocal())}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: active, onChanged: (v) => _toggle(r, v)),
                IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(r)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
