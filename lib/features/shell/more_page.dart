import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import '../../core/widgets/motion.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/ui_kit.dart';
import 'nav_items.dart';
import '../../core/widgets/glass_app_bar.dart';

/// Semua menu: cari menu, menu favorit (tahan ubin untuk menyematkan), lalu kelompok menu.
class MorePage extends StatefulWidget {
  const MorePage({super.key});

  /// Kelompok menu (dipakai juga oleh sidebar tablet/web di AppShell).
  static const groups = <(String, List<String>)>[
    ('Organisasi', ['Profil Organisasi', 'Struktur Organisasi', 'Buku Saku', 'Anggota', 'Pendaftaran', 'Cabang', 'Informasi', 'Event', 'Donasi', 'Forum', 'Kalender', 'AI PERKAPI']),
    ('Profesi', ['Peraturan & Hukum', 'Pendaftaran AHU', 'Perpanjangan AHU', 'Format Laporan AHU', 'Data AHU Saya']),
    ('Akun & sistem', ['Profil', 'Kartu Anggota', 'Verifikasi QR', 'Chat', 'Keamanan & SOS', 'Pelacakan GPS', 'Area (Geofence)', 'Pengumuman Massal', 'Laporan & Ekspor', 'Kotak masuk', 'Audit Log', 'Pengaturan', 'Dashboard']),
  ];

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  static const _favKey = 'menu_favorites';
  final _q = TextEditingController();
  List<String> _fav = [];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _fav = p.getStringList(_favKey) ?? []);
    });
    _q.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _toggleFav(String label) async {
    successHaptic();
    setState(() {
      if (_fav.contains(label)) {
        _fav.remove(label);
      } else {
        _fav.add(label);
      }
    });
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_favKey, _fav);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_fav.contains(label) ? '$label disematkan ke Favorit' : '$label dilepas dari Favorit')));
  }

  Widget _grid(BuildContext context, List<NavItem> list, {bool hero = true}) => AppCard(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
        child: GridView(
          padding: EdgeInsets.zero,
          gridDelegate: quickTileGrid(context, spacing: 2),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var k = 0; k < list.length; k++)
              PopIn(
                index: k,
                child: GestureDetector(
                  onLongPress: () => _toggleFav(list[k].label),
                  child: QuickTile(
                    heroTag: hero ? 'tile:${list[k].route.split('/').where((e) => e.isNotEmpty).last}' : null,
                    icon: list[k].icon,
                    label: list[k].label,
                    color: AppColors.forKey(list[k].route),
                    onTap: () => context.push(list[k].route),
                  ),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = {for (final i in allItems.where((i) => Access.instance.can(i.perm))) i.label: i};
    final q = _q.text.trim().toLowerCase();
    final found = q.isEmpty ? <NavItem>[] : items.values.where((i) => i.label.toLowerCase().contains(q)).toList();
    final favs = [for (final l in _fav) if (items[l] != null) items[l]!];
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('Semua menu')),
      body: ListView(padding: barPad(context, EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom)), children: [
        // kolom cari berbentuk kapsul
        TextField(
          controller: _q,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari menu',
            prefixIcon: const Icon(CupertinoIcons.search),
            suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(CupertinoIcons.xmark), tooltip: 'Hapus', onPressed: _q.clear),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (q.isNotEmpty) ...[
          SectionHeader('Hasil pencarian'),
          const SizedBox(height: AppSpace.sm),
          if (found.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
              child: Text('Tidak ada menu "$q".', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          else
            _grid(context, found),
        ] else ...[
          if (favs.isNotEmpty) ...[
            const SectionHeader('Favorit'),
            const SizedBox(height: AppSpace.sm),
            _grid(context, favs, hero: false),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.xs),
              child: Text('Tip: tahan ubin menu untuk menyematkannya ke Favorit.',
                  style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
            ),
          for (final g in MorePage.groups)
            if (g.$2.any(items.containsKey)) ...[
              SectionHeader(g.$1),
              const SizedBox(height: AppSpace.sm),
              _grid(context, [for (final l in g.$2) if (items[l] != null) items[l]!]),
            ],
        ],
      ]),
    );
  }
}
