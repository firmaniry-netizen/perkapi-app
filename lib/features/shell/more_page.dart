import 'package:flutter/material.dart';
import '../../core/widgets/motion.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/ui_kit.dart';
import 'nav_items.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  /// Kelompok menu (dipakai juga oleh sidebar tablet/web di AppShell).
  static const groups = <(String, List<String>)>[
    ('Organisasi', ['Profil Organisasi', 'Struktur Organisasi', 'Buku Saku', 'Anggota', 'Pendaftaran', 'Cabang', 'Informasi', 'Event', 'Forum', 'Kalender', 'AI PERKAPI']),
    ('Profesi', ['Peraturan & Hukum', 'Pendaftaran AHU', 'Perpanjangan AHU', 'Format Laporan AHU', 'Data AHU Saya']),
    ('Akun & sistem', ['Profil', 'Kartu Anggota', 'Verifikasi QR', 'Chat', 'Keamanan & SOS', 'Pelacakan GPS', 'Area (Geofence)', 'Pengumuman Massal', 'Laporan & Ekspor', 'Kotak masuk', 'Audit Log', 'Pengaturan', 'Dashboard']),
  ];

  @override
  Widget build(BuildContext context) {
    final items = {for (final i in allItems.where((i) => Access.instance.can(i.perm))) i.label: i};
    return Scaffold(
      appBar: AppBar(title: const Text('Semua menu')),
      body: ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.paddingOf(context).bottom), children: [
        for (final g in groups)
          if (g.$2.any(items.containsKey)) ...[
            SectionHeader(g.$1),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(8),
              child: GridView(
                gridDelegate: quickTileGrid(context),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final l in g.$2)
                    if (items[l] != null)
                      PopIn(
                        index: g.$2.indexOf(l),
                        child: QuickTile(heroTag: 'tile:${items[l]!.route.split('/').where((e) => e.isNotEmpty).last}', icon: items[l]!.icon, label: l, color: AppColors.forKey(items[l]!.route), onTap: () => context.push(items[l]!.route)),
                      ),
                ],
              ),
            ),
          ],
      ]),
    );
  }
}
