import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/ui_kit.dart';
import '../profession/guide_widgets.dart';
import 'regulation_data.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/constants/app_tokens.dart';

/// Peraturan & hukum: daftar aturan yang relevan bagi kurator/pengurus, dengan tombol unduh PDF.
/// Unduhan dibuka lewat peramban/penampil PDF perangkat dari sumber resmi (tidak disimpan di server PERKAPI).
class RegulationsPage extends StatefulWidget {
  const RegulationsPage({super.key});
  @override
  State<RegulationsPage> createState() => _RegulationsPageState();
}

class _RegulationsPageState extends State<RegulationsPage> {
  String _q = '';
  RegulationKind? _kind;
  List<Regulation> _items = regulations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Daftar terbaru dari database (sama dengan situs). Gagal/kosong = tetap memakai daftar bawaan.
  Future<void> _load() async {
    try {
      final rows = List<Map<String, dynamic>>.from(await SupabaseService.client.rpc('public_regulations') as List);
      if (rows.isNotEmpty && mounted) setState(() => _items = rows.map(regulationFromRow).toList());
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka tautan ini.')));
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tautan disalin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final list = [
      for (final r in _items)
        if ((_kind == null || r.kind == _kind) && (q.isEmpty || r.searchText.contains(q))) r,
    ];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('Peraturan & Hukum')),
      body: PageGlow(
        accent: AppColors.navyAction,
        child: ListView(
          padding: barPad(context, EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom)),
          children: [
            Reveal(
              index: 0,
              dy: -12,
              child: ScreenHero(
                title: 'Peraturan & Hukum',
                subtitle: 'Dasar hukum kurator, pengurus, kepailitan, dan PKPU. Unduh langsung dari sumber resmi.',
                icon: PhFill.gavel,
                accent: AppColors.navyAction,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Ph.magnifyingGlass),
                hintText: 'Cari peraturan (mis. imbalan jasa, pendaftaran)',
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: const Text('Semua'), selected: _kind == null, onSelected: (_) => setState(() => _kind = null)),
                ),
                for (final k in RegulationKind.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(k.label), selected: _kind == k, onSelected: (_) => setState(() => _kind = k)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              AppCard(child: Text('Tidak ada peraturan yang cocok. Coba kata kunci lain atau cari di portal resmi di bawah.', style: TextStyle(color: sc.onSurfaceVariant)))
            else
              for (var i = 0; i < list.length; i++) ...[
                const SizedBox(height: 12),
                Reveal(index: i + 1, child: _card(context, list[i])),
              ],
            const SizedBox(height: 8),
            const GuideCard(
              title: 'Cari peraturan lain',
              subtitle: 'Untuk perubahan terbaru, peraturan pemerintah, atau PERMA/SEMA yang belum ada di daftar ini.',
              child: SizedBox.shrink(),
            ),
            for (final p in regulationPortals)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppCard(
                  onTap: () => _open(p.$3),
                  child: Row(children: [
                    const SolidTile(icon: Ph.globe, color: AppColors.sky, size: 40, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(p.$2, style: TextStyle(fontSize: AppType.small, height: 1.35, color: sc.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Ph.arrowSquareOut, size: 18, color: sc.onSurfaceVariant),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                'Daftar ini dikumpulkan dari portal resmi pemerintah dan Mahkamah Konstitusi. Ini bukan nasihat hukum. '
                'Peraturan dapat berubah atau dicabut, jadi pastikan status berlakunya sebelum dikutip dalam laporan atau permohonan.',
                style: TextStyle(fontSize: AppType.caption, height: 1.45, color: sc.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Regulation r) {
    final sc = Theme.of(context).colorScheme;
    final color = switch (r.kind) {
      RegulationKind.uu => AppColors.navyAction,
      RegulationKind.permen => AppColors.teal,
      RegulationKind.putusan => AppColors.violet,
      RegulationKind.rancangan => AppColors.amber,
    };
    final main = r.pdfUrl ?? r.pageUrl;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SolidTile(icon: switch (r.kind) {
            RegulationKind.putusan => Ph.gavel,
            RegulationKind.rancangan => Ph.notePencil,
            _ => Ph.fileText,
          }, color: color, size: 44, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.kind.label.toUpperCase(), style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: color)),
              const SizedBox(height: 2),
              Text(r.number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.lead, height: 1.3)),
              if (r.title.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('tentang ${r.title}', style: TextStyle(fontSize: AppType.small, height: 1.35, color: sc.onSurfaceVariant)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(r.summary, style: const TextStyle(height: 1.4, fontSize: AppType.body)),
        if (r.note != null) ...[
          const SizedBox(height: 10),
          GuideCallout(text: r.note!, icon: Ph.info, color: AppColors.amber),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (r.pdfUrl != null)
            FilledButton.icon(onPressed: () => _open(r.pdfUrl!), icon: const Icon(Ph.downloadSimple, size: 18), label: const Text('Unduh PDF')),
          if (r.pageUrl != null)
            OutlinedButton.icon(onPressed: () => _open(r.pageUrl!), icon: const Icon(Ph.arrowSquareOut, size: 18), label: Text(r.pageLabel)),
          if (main != null)
            TextButton.icon(onPressed: () => _copy(main), icon: const Icon(Ph.link, size: 18), label: const Text('Salin tautan')),
        ]),
      ]),
    );
  }
}
