import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/format_id.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/repositories/data_repository.dart';
import '../../shared/widgets/state_widgets.dart';
import '../alerts/alert_banner.dart';
import '../alerts/alert_service.dart';
import '../news/news_post.dart';
import '../news/news_widgets.dart';
import 'member_hero_card.dart';

/// Beranda (redesain 3.0): satu titik fokus (kartu anggota 3D), lalu hal yang paling sering dicari:
/// pintasan, agenda terdekat, berita, informasi. Statistik & kartu AI dihapus (AI kini satu ubin pintasan).
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_Data> _f = _load();
  final _scroll = ScrollController();
  int _notifUnread = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<_Data> _load() async {
    final me = Access.instance.memberId ?? '';
    final unread = await DataRepository.count('notifications', eq: {'member_id': me, 'is_read': false});
    if (mounted) setState(() => _notifUnread = unread);
    List<Map<String, dynamic>> news = [], events = [];
    NewsFeed? feed;
    try {
      feed = await NewsRepository.load(postLimit: 5, coversOnly: true);
    } catch (_) {}
    try {
      news = List<Map<String, dynamic>>.from(await SupabaseService.client
          .from('announcements')
          .select('id,title,category,created_at')
          .order('created_at', ascending: false)
          .limit(3));
    } catch (_) {}
    try {
      // Mulai dari awal hari ini agar acara yang sedang berlangsung hari ini tetap tampil.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      events = List<Map<String, dynamic>>.from(await SupabaseService.client
          .from('events')
          .select('id,title,starts_at,location')
          .gte('starts_at', today)
          .order('starts_at')
          .limit(6));
    } catch (_) {}
    return _Data(news, events, feed);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Positioned.fill(
            child: FutureBuilder<_Data>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(padding: EdgeInsets.only(top: 64), child: SkeletonList(count: 5, height: 96));
                }
                if (snap.hasError || snap.data == null) {
                  return Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: ErrorState(
                          message: 'Gagal memuat beranda. Periksa koneksi lalu coba lagi.',
                          onRetry: () => setState(() => _f = _load())));
                }
                final d = snap.data!;
                return RefreshIndicator(
                  edgeOffset: 64,
                  onRefresh: () async {
                    AlertService.instance.refresh();
                    setState(() => _f = _load());
                  },
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 72, 20, 130),
                    children: [
                      // Banner peringatan muncul/hilang tanpa membuat isi di bawahnya melompat (padanan layout transition).
                      AnimatedSize(
                        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 300),
                        curve: const Cubic(0.2, 0, 0, 1),
                        alignment: Alignment.topCenter,
                        child: const AlertBanner(),
                      ),
                      // Kartu anggota: mengecil & meredup halus saat digulir (kedalaman), lalu konten lewat di depannya.
                      _ScrollDepth(
                        controller: _scroll,
                        child: MemberHeroCard(onOpen: () => context.push('/member-card')),
                      ),
                      const SizedBox(height: 18),
                      Reveal(
                        index: 1,
                        dy: 12,
                        child: AppCard(
                          radius: AppRadius.card,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          onTap: () => context.push('/search'),
                          child: Row(children: [
                            Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Cari anggota, catatan, peraturan',
                                  overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant)),
                            ),
                          ]),
                        ),
                      ),
                      const SectionHeader('Akses cepat'),
                      const SizedBox(height: 8),
                      _quickGrid(context),
                      SectionHeader('Agenda terdekat', actionLabel: 'Kalender', onAction: () => context.push('/calendar')),
                      const SizedBox(height: 10),
                      _AgendaStrip(events: d.events),
                      SectionHeader('Berita terbaru', actionLabel: 'Lihat semua', onAction: () => context.push('/gallery')),
                      const SizedBox(height: 8),
                      Reveal(index: 3, dy: 18, child: _newsSection(context, d.feed)),
                      SectionHeader('Informasi terbaru',
                          actionLabel: 'Lihat semua', onAction: () => context.push('/organization-info')),
                      const SizedBox(height: 8),
                      _infoCard(context, d.news),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _GlassHeader(controller: _scroll, child: _header(context, a, scheme))),
        ]),
      ),
    );
  }

  Widget _header(BuildContext context, Access a, ColorScheme scheme) {
    return Reveal(
      dy: -10,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: ListenableBuilder(
              listenable: Access.instance,
              builder: (_, __) => MemberAvatar(name: a.name, path: a.avatarPath, radius: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_greeting(), style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
              Text(a.name.split(' ').first,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.accent(24, color: Theme.of(context).brightness == Brightness.dark ? AppColors.gold : AppColors.goldDeep, height: 1.05)),
            ]),
          ),
          AppIconButton(icon: Icons.apps_rounded, tooltip: 'Semua menu', onTap: () => context.push('/more')),
          const SizedBox(width: 8),
          // SATU lonceng: kotak masuk berisi Peringatan + Notifikasi (lencana = jumlah keduanya).
          ListenableBuilder(
            listenable: AlertService.instance,
            builder: (context, _) => AppIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Kotak masuk',
              badge: AlertService.instance.unread + _notifUnread,
              pulse: true,
              onTap: () async {
                await context.push('/inbox');
                if (mounted) setState(() => _f = _load());
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// 7 pintasan + "Semua menu" (2 baris x 4). Yang sudah ada di navigasi bawah (Buku Saku, Profesi, Informasi) tidak diulang.
  Widget _quickGrid(BuildContext context) {
    final tiles = <(IconData, String, String)>[
      (Icons.newspaper_rounded, 'Berita', '/gallery'),
      (Icons.event_rounded, 'Agenda', '/events'),
      (Icons.gavel_rounded, 'Peraturan', '/regulations'),
      (Icons.forum_rounded, 'Forum', '/forum'),
      (Icons.chat_bubble_rounded, 'Chat', '/chat'),
      (Icons.auto_awesome_rounded, 'Tanya AI', '/ai'),
      (Icons.calendar_month_rounded, 'Kalender', '/calendar'),
      (Icons.grid_view_rounded, 'Semua', '/more'),
    ];
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: quickTileGrid(context),
      children: [
        for (var k = 0; k < tiles.length; k++)
          PopIn(
            index: k,
            child: QuickTile(
              heroTag: 'tile:${tiles[k].$3.split('/').where((e) => e.isNotEmpty).last}',
              icon: tiles[k].$1,
              label: tiles[k].$2,
              color: tiles[k].$3 == '/more' ? AppColors.navy : AppColors.forKey(tiles[k].$3),
              onTap: () => context.push(tiles[k].$3),
            ),
          ),
      ],
    );
  }

  /// Berita terbaru: tampil untuk SEMUA pengguna. Tombol hapus hanya muncul bagi admin.
  Widget _newsSection(BuildContext context, NewsFeed? feed) {
    final scheme = Theme.of(context).colorScheme;
    final posts = feed?.posts ?? const <NewsPost>[];
    if (posts.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('/gallery?add=1'),
        child: Row(children: [
          const SolidTile(icon: Icons.newspaper_rounded, color: AppColors.goldDeep, size: 52, radius: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Belum ada berita', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('Tulis kabar kegiatan pertama. Berita tampil di beranda semua anggota.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
            ]),
          ),
          const Icon(Icons.add_circle_rounded, color: AppColors.red, size: 30),
        ]),
      );
    }
    return NewsCarousel(
      posts: posts,
      urls: feed!.urls,
      onOpen: (p) => context.push('/gallery?post=${p.id}'),
      onDelete: Access.instance.isAdmin ? _deleteNews : null,
    );
  }

  Future<void> _deleteNews(NewsPost p) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDeleteNews(context, p)) return;
    try {
      await NewsRepository.delete(p);
      messenger.showSnackBar(const SnackBar(content: Text('Berita dihapus.')));
      if (mounted) setState(() => _f = _load());
    } on NewsForbiddenException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Gagal menghapus berita. Coba lagi.')));
    }
  }

  Widget _infoCard(BuildContext context, List<Map<String, dynamic>> rows) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      return AppCard(
        child: Text('Belum ada informasi. Pengumuman dari pengurus akan tampil di sini.',
            style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      final n = rows[i];
      children.add(ListTile(
        onTap: () => context.push('/module/announcements/${n['id']}'),
        minTileHeight: 64,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const SolidTile(icon: Icons.campaign_rounded, color: AppColors.goldDeep, size: 44, radius: 14),
        title: Text('${n['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${n['category'] ?? 'Pengumuman'} • ${fmtValue(n['created_at'])}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
      ));
      if (i < rows.length - 1) children.add(const Divider(indent: 76));
    }
    return Reveal(index: 4, child: AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)));
  }
}

class _Data {
  _Data(this.news, this.events, this.feed);
  final List<Map<String, dynamic>> news, events;
  final NewsFeed? feed; // berita terbaru (galeri berita) untuk semua pengguna
}

/// Agenda terdekat: kartu tanggal yang digeser ke samping. Tanggal besar memakai huruf judul situs + emas.
class _AgendaStrip extends StatelessWidget {
  const _AgendaStrip({required this.events});
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (events.isEmpty) {
      return AppCard(
        onTap: Access.instance.can('manage_event') ? () => context.push('/module/events/new') : null,
        child: Row(children: [
          const SolidTile(icon: Icons.event_available_rounded, color: AppColors.goldDeep, size: 48, radius: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              Access.instance.can('manage_event')
                  ? 'Belum ada agenda. Ketuk untuk membuat agenda pertama.'
                  : 'Belum ada agenda. Agenda dari pengurus akan muncul di sini.',
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
            ),
          ),
        ]),
      );
    }
    final ts = MediaQuery.textScalerOf(context);
    return SizedBox(
      height: 132 + ts.scale(14) * 2.6,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final e = events[i];
          final t = FmtId.parse(e['starts_at']);
          final timed = FmtId.hasTime(e['starts_at']);
          return Reveal(
            index: i,
            dy: 0,
            child: SizedBox(
              width: 220,
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                onTap: () => context.push('/module/events/${e['id']}'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(t == null ? '-' : '${t.day}',
                        style: AppType.headline(36, color: dark ? AppColors.gold : AppColors.goldDeep, height: 1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t == null ? '' : FmtId.monthsLong[t.month - 1].toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        Text(t == null ? '' : FmtId.relativeDay(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                  const Spacer(),
                  Text('${e['title']}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                    [if (timed && t != null) FmtId.time(t), '${e['location'] ?? 'Lokasi belum diisi'}'].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kedalaman saat menggulir: [child] mengecil hingga 94% dan meredup hingga 55% dalam 260 px pertama.
/// Hanya transform + opacity (murah). Mati saat "kurangi gerak".
class _ScrollDepth extends StatelessWidget {
  const _ScrollDepth({required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, c) {
        final off = controller.hasClients ? controller.offset : 0.0;
        final p = (off / 260).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - 0.45 * p,
          child: Transform.scale(scale: 1 - 0.06 * p, alignment: Alignment.topCenter, child: c),
        );
      },
    );
  }
}

/// Header beranda: transparan di puncak, lalu berubah menjadi kaca buram + garis tipis saat daftar digulir.
/// Blur baru dipasang setelah ada gulir (hemat tenaga di HP menengah).
class _GlassHeader extends StatelessWidget {
  const _GlassHeader({required this.controller, required this.child});
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final line = theme.dividerTheme.color ?? Colors.transparent;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, c) {
        final off = controller.hasClients ? controller.offset : 0.0;
        final t = (off / 24).clamp(0.0, 1.0);
        final bar = DecoratedBox(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.80 * t),
            border: Border(bottom: BorderSide(color: line.withValues(alpha: t))),
          ),
          child: c,
        );
        if (t == 0) return bar;
        return ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: bar));
      },
    );
  }
}
