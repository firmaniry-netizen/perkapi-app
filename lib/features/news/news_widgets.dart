import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/smooth_overlays.dart';
import 'news_post.dart';

/// Sampul berita: gradasi dongker + gambar bawaan (opsional) + foto berita yang memudar masuk.
class NewsCover extends StatelessWidget {
  const NewsCover({super.key, this.url, this.cacheWidth = 720});
  final String? url;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF1B4A9C)],
          ),
        ),
      ),
      Image.asset(AppAssets.newsPlaceholder, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      if (url == null)
        const Center(child: Icon(Icons.newspaper_rounded, size: 40, color: Color(0x33FFFFFF))),
      if (url != null)
        Image.network(
          url!,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.low,
          frameBuilder: (ctx, child, frame, sync) =>
              sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 320), child: child),
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54)),
        ),
    ]);
  }
}

/// Pil kategori (album) berwarna.
class NewsPill extends StatelessWidget {
  const NewsPill(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color ?? newsAlbumColor(text), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 4)],
          Flexible(
            child: Text(text.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          ),
        ]),
      );
}

/// Tombol bulat kaca di atas foto (kembali, hapus).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({super.key, required this.icon, required this.onTap, this.tooltip, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Pressable(
          onTap: onTap,
          scale: 0.9,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color ?? const Color(0x66000000),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      );
}

/// Dialog konfirmasi hapus berita (khusus admin). Mengembalikan true bila dikonfirmasi.
Future<bool> confirmDeleteNews(BuildContext context, NewsPost p) async {
  final ok = await showSmoothDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.delete_forever_rounded, color: AppColors.red, size: 28),
      ),
      title: const Text('Hapus berita ini?'),
      content: Text(
        '"${p.title}" beserta ${p.rows.length} foto akan dihapus permanen untuk semua pengguna. Tindakan ini tidak dapat dibatalkan.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(110, 46)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Carousel "Berita terbaru" di dashboard. Terlihat oleh semua pengguna; tombol hapus hanya untuk admin.
class NewsCarousel extends StatefulWidget {
  const NewsCarousel({
    super.key,
    required this.posts,
    required this.urls,
    required this.onOpen,
    this.onDelete,
  });
  final List<NewsPost> posts;
  final Map<String, String> urls;
  final void Function(NewsPost) onOpen;
  final void Function(NewsPost)? onDelete; // null = bukan admin

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  final _pc = PageController(viewportFraction: 0.9);
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = ((w - 40) * 0.9 * 0.68).clamp(180.0, 280.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      SizedBox(
        height: h,
        child: PageView.builder(
          controller: _pc,
          padEnds: false,
          clipBehavior: Clip.none,
          itemCount: widget.posts.length,
          onPageChanged: (v) => setState(() => _i = v),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _card(widget.posts[i]),
          ),
        ),
      ),
      if (widget.posts.length > 1) ...[
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var k = 0; k < widget.posts.length; k++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: k == _i ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: k == _i ? AppColors.red : (dark ? AppColors.navyLine : AppColors.line),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ]),
      ],
    ]);
  }

  Widget _card(NewsPost p) {
    final accent = newsAlbumColor(p.album);
    return Pressable(
      onTap: () => widget.onOpen(p),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.26), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Stack(fit: StackFit.expand, children: [
          NewsCover(url: widget.urls[p.paths.first], cacheWidth: 900),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Colors.transparent, Color(0xF008142E)],
                stops: [0, 0.38, 1],
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: () => widget.onOpen(p)),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            right: widget.onDelete != null ? 62 : 14,
            child: Row(children: [
              Flexible(child: NewsPill(p.album, color: accent, icon: newsAlbumIcon(p.album))),
              if (p.isFresh) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(12)),
                  child: const Text('BARU',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ),
              ],
            ]),
          ),
          if (widget.onDelete != null)
            Positioned(
              right: 10,
              top: 10,
              child: GlassCircleButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Hapus berita (admin)',
                onTap: () => widget.onDelete!(p),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xCCFFFFFF)),
                const SizedBox(width: 4),
                Text(timeAgoId(p.date),
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                const Icon(Icons.photo_library_rounded, size: 14, color: Color(0xCCFFFFFF)),
                const SizedBox(width: 4),
                Text('${p.rows.length}',
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
