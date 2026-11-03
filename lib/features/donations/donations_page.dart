import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/utils/format_id.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import 'donation_data.dart';
import 'donation_widgets.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/constants/app_tokens.dart';

/// Donasi: daftar kampanye (event, sosial, bencana, pendidikan, organisasi) dan riwayat donasi saya.
class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});
  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  late Future<List<Campaign>> _f = DonationRepo.campaigns();
  Future<List<Map<String, dynamic>>>? _mine;
  String? _cat;
  int _tab = 0;

  bool get _manager => Access.instance.can('manage_donation') || Access.instance.isAdmin;

  Future<void> _reload() async {
    setState(() {
      _f = DonationRepo.campaigns();
      _mine = null;
    });
    await _f;
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('Donasi')),
      floatingActionButton: _manager
          ? FloatingActionButton.extended(
              onPressed: () => _open('/donations/new'),
              icon: const Icon(CupertinoIcons.add),
              label: const Text('Buat kampanye'),
            )
          : null,
      body: PageGlow(
        accent: AppColors.emerald,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: barPad(context, EdgeInsets.fromLTRB(16, 16, 16, 96 + bottom)),
            children: [
              const Reveal(
                index: 0,
                dy: -12,
                child: ScreenHero(
                  title: 'Donasi PERKAPI',
                  subtitle: 'Dukung event organisasi, kegiatan sosial, dan bantuan bencana bersama sesama anggota.',
                  icon: CupertinoIcons.heart_circle,
                  accent: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Kampanye'), icon: Icon(CupertinoIcons.speaker_2_fill)),
                  ButtonSegment(value: 1, label: Text('Donasi saya'), icon: Icon(CupertinoIcons.doc_text)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 12),
              if (_tab == 0) ..._campaigns(context) else _myDonations(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _campaigns(BuildContext context) => [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: const Text('Semua'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
            ),
            for (final c in donationCategories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(categoryStyle(c).$2, size: 16),
                  label: Text(c),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = _cat == c ? null : c),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 4),
        FutureBuilder<List<Campaign>>(
          future: _f,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const SkeletonList(count: 3);
            }
            if (s.hasError) {
              return ErrorState(message: 'Donasi belum bisa dimuat. Periksa koneksi internet Anda.', onRetry: _reload);
            }
            final list = [for (final c in s.data!) if (_cat == null || c.category == _cat) c];
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: CupertinoIcons.heart_circle,
                  title: 'Belum ada kampanye',
                  message: _manager
                      ? 'Buat kampanye donasi pertama, misalnya untuk event atau kegiatan sosial.'
                      : 'Kampanye donasi dari pengurus akan tampil di sini.',
                ),
              );
            }
            return Column(children: [
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Reveal(index: i + 1, child: CampaignCard(c: list[i], onTap: () => _open('/donations/${list[i].id}'))),
                ),
            ]);
          },
        ),
      ];

  Widget _myDonations(BuildContext context) {
    final me = Access.instance.memberId;
    if (me == null) return const EmptyState(message: 'Masuk sebagai anggota untuk melihat donasi Anda.');
    _mine ??= DonationRepo.mine(me);
    final sc = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _mine,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const SkeletonList(count: 3);
        }
        final rows = s.data ?? const [];
        if (rows.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyState(icon: CupertinoIcons.doc_text, title: 'Belum ada donasi', message: 'Donasi yang Anda kirim akan tercatat di sini beserta statusnya.'),
          );
        }
        final total = rows.where((r) => r['status'] == 'terverifikasi').fold<int>(0, (a, r) => a + ((r['amount'] as num?)?.toInt() ?? 0));
        return Column(children: [
          AppCard(
            wash: AppColors.emerald,
            child: Row(children: [
              const SolidTile(icon: CupertinoIcons.heart_fill, color: AppColors.emerald, size: 44, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total donasi diterima', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                  Text(rupiah(total), style: const TextStyle(fontSize: AppType.title, fontWeight: FontWeight.w900)),
                ]),
              ),
              Text('${rows.length} kali', style: TextStyle(color: sc.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ]),
          ),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: AppCard(
                onTap: () => _open('/donations/${r['campaign_id']}'),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(r['donation_campaigns'] as Map?)?['title'] ?? 'Kampanye'}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${rupiah((r['amount'] as num?) ?? 0)} · ${FmtId.value(r['created_at'])}',
                          style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Builder(builder: (_) {
                    final (c, l, i) = donationStatus('${r['status']}');
                    return Pill(l, color: c, icon: i);
                  }),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
