import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';

import '../../core/services/access_service.dart';
import '../../core/widgets/icon_badge.dart';
import '../../shared/widgets/state_widgets.dart';
import 'export_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/constants/app_colors.dart';

/// Pengurus: ekspor data anggota dan agenda ke CSV/PDF.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  bool get _allowed => Access.instance.can('view_reports');

  Future<void> _export(BuildContext context, Future<int> Function() job) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final n = await job();
      messenger.showSnackBar(SnackBar(content: Text('$n baris diekspor.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal mengekspor.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const AccessDenied();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan & Ekspor')),
      body: PageGlow(accent: AppColors.red, child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        const ScreenHero(
          title: 'Laporan & Ekspor',
          subtitle: 'Rekap data organisasi, siap diunduh',
          icon: Icons.insights_rounded,
          accent: AppColors.red,
        ),
        const SizedBox(height: 22),
        Text('Ekspor data', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('File CSV bisa dibuka di Excel. Hanya data yang boleh Anda lihat yang ikut terekspor.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 10),
        for (final e in <(String, IconData, String)>[
          ('Daftar anggota', Icons.badge_outlined, 'members'),
          ('Agenda & event', Icons.event_outlined, 'events'),
        ])
          Card(
            child: ListTile(
              leading: IconBadge(e.$2, size: 40),
              title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  onPressed: () => _export(context, () => ExportService.exportModule(e.$3)),
                  child: const Text('CSV'),
                ),
                TextButton(
                  onPressed: () => _export(context, () => ExportService.exportModule(e.$3, pdf: true)),
                  child: const Text('PDF'),
                ),
              ]),
            ),
          ),
      ])),
    );
  }
}
