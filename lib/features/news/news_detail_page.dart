import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/motion.dart';
import 'news_post.dart';
import 'news_widgets.dart';

/// Halaman berita modern: foto sampul besar (geser untuk foto lain), lembar isi melengkung,
/// kategori berwarna, tanggal, tulisan, dan deretan foto kecil.
/// [onDelete] hanya diberikan untuk admin; null berarti tombol hapus tidak tampil.
/// onDelete mengembalikan true bila berhasil dihapus (halaman lalu ditutup).
class NewsDetailPage extends StatefulWidget {
  const NewsDetailPage({super.key, required this.post, required this.urls, this.onDelete});
  final NewsPost post;
  final Map<String, String> urls;
  final Future<bool> Function()? onDelete;

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  final _pc = PageController();
  late final Map<String, String> _urls = {...widget.urls};
  int _i = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // Dashboard hanya membawa foto sampul; foto lainnya ditandatangani di sini.
    final missing = [for (final p in widget.post.paths) if (!_urls.containsKey(p)) p];
    if (missing.isNotEmpty) {
      NewsRepository.signUrls(missing).then((m) {
        if (mounted) setState(() => _urls.addAll(m));
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (widget.onDelete == null || _deleting) return;
    if (!await confirmDeleteNews(context, widget.post)) return;
    setState(() => _deleting = true);
    final ok = await widget.onDelete!();
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _deleting = false);
    }
  }

  void _viewer(int start) {
    final p = widget.post;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewsPhotoViewer(paths: p.paths, urls: _urls, start: start),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final sc = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final accent = newsAlbumColor(p.album);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          expandedHeight: 360 + top,
          backgroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 60,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: GlassCircleButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Kembali',
                onTap: () => Navigator.maybePop(context),
              ),
            ),
          ),
          actions: [
            if (widget.onDelete != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: _deleting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : GlassCircleButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Hapus berita (admin)',
                          color: const Color(0x99C8202F),
                          onTap: _delete,
                        ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: Stack(fit: StackFit.expand, children: [
              PageView.builder(
                controller: _pc,
                itemCount: p.rows.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _viewer(i),
                  child: NewsCover(url: _urls[p.paths[i]], cacheWidth: 1100),
                ),
              ),
              // Gradasi atas (agar tombol terbaca) dan bawah (menyatu dengan lembar isi).
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent, Colors.transparent, Color(0x55000000)],
                      stops: [0, 0.28, 0.7, 1],
                    ),
                  ),
                ),
              ),
              if (p.rows.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var k = 0; k < p.rows.length; k++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: k == _i ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: k == _i ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ]),
                ),
              // Lembar isi melengkung yang naik menutupi bawah foto.
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 4, 22, 40 + MediaQuery.paddingOf(context).bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Reveal(
                dy: 12,
                child: Row(children: [
                  Flexible(child: NewsPill(p.album, color: accent, icon: newsAlbumIcon(p.album))),
                  if (p.isFresh) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(12)),
                      child: const Text('BARU',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Reveal(
                index: 1,
                dy: 14,
                child: Text(p.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.25)),
              ),
              const SizedBox(height: 12),
              Reveal(
                index: 2,
                dy: 10,
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: sc.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(formatTanggal(p.date),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sc.onSurfaceVariant)),
                  const SizedBox(width: 14),
                  Icon(Icons.photo_library_rounded, size: 15, color: sc.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${p.rows.length} foto',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sc.onSurfaceVariant)),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 18),
              if (p.body.isEmpty)
                Text('Tidak ada tulisan.', style: TextStyle(color: sc.onSurfaceVariant))
              else
                Reveal(
                  index: 3,
                  dy: 10,
                  child: SelectableText(p.body, style: const TextStyle(fontSize: 16, height: 1.7)),
                ),
              if (p.rows.length > 1) ...[
                const SizedBox(height: 28),
                const Text('Foto kegiatan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: p.rows.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => Pressable(
                      onTap: () => _viewer(i),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(width: 92, height: 92, child: NewsCover(url: _urls[p.paths[i]], cacheWidth: 300)),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Penampil foto layar penuh (geser, cubit untuk zoom).
class NewsPhotoViewer extends StatefulWidget {
  const NewsPhotoViewer({super.key, required this.paths, required this.urls, required this.start});
  final List<String> paths;
  final Map<String, String> urls;
  final int start;
  @override
  State<NewsPhotoViewer> createState() => _NewsPhotoViewerState();
}

class _NewsPhotoViewerState extends State<NewsPhotoViewer> {
  late final _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      appBar: AppBar(
        backgroundColor: AppColors.navyDeep,
        foregroundColor: Colors.white,
        title: Text('${_i + 1}/${widget.paths.length}', style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.paths.length,
        onPageChanged: (v) => setState(() => _i = v),
        itemBuilder: (_, i) {
          final url = widget.urls[widget.paths[i]];
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: url == null
                  ? const CircularProgressIndicator(color: Colors.white54)
                  : Image.network(url, fit: BoxFit.contain, cacheWidth: 1600),
            ),
          );
        },
      ),
    );
  }
}
