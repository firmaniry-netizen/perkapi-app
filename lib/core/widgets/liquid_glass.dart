import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'motion.dart' show reduceMotion, tapHaptic;

/// "Liquid Glass" PERKAPI v2 — kaca cair ala iOS 26 untuk elemen yang MENGAMBANG di atas isi
/// (navigasi bawah, header yang menempel, tombol bulat, gelembung aksi, lembar bawah).
///
/// Lapisan (dari bawah ke atas):
///  1. latar di belakang diburamkan + saturasinya dinaikkan (warna di bawah kaca jadi lebih hidup),
///  2. tint tipis sesuai tema (varian [clear] lebih bening untuk di atas foto/warna kuat),
///  3. pita pembiasan di tepi dalam — tepi kaca tebal memantulkan cahaya, jadi tepi lebih terang dari tengah,
///  4. kilau tepi (rim) — terang di kiri-atas dan menyala lagi tipis di kanan-bawah (cahaya yang dibelokkan),
///  5. sorotan specular di separuh atas + kaustik tipis di dasar,
///  6. bayangan lembut di luar.
///
/// Aksesibilitas: bila "Tingkatkan kontras" aktif (MediaQuery.highContrast), kaca menjadi permukaan padat
/// bergaris tegas, tanpa blur. Blur itu berat — pakai hanya untuk elemen mengambang yang sedikit.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = 20,
    this.padding = EdgeInsets.zero,
    this.tint,
    this.shadow = true,
    this.shape = BoxShape.rectangle,
    this.clear = false,
    this.glow,
  });

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry padding;

  /// Warna tint kustom (default mengikuti tema). Untuk kaca berwarna (mis. tombol merah) beri alfa < 1.
  final Color? tint;
  final bool shadow;

  /// [BoxShape.circle] untuk tombol bulat.
  final BoxShape shape;

  /// Varian bening: tint sangat tipis, cocok di atas foto/kartu berwarna.
  final bool clear;

  /// Pendar warna di bawah kaca (mis. merah untuk tombol aksi). Null = bayangan netral.
  final Color? glow;

  static const saturate = <double>[
    // matriks saturasi 1.6 (koefisien luminans Rec.709)
    1.4724, -0.4291, -0.0433, 0, 0,
    -0.1276, 1.1709, -0.0433, 0, 0,
    -0.1276, -0.4291, 1.5567, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Filter latar kaca (blur + saturasi) — dipakai juga oleh header & lembar bawah.
  static ImageFilter backdrop(double blur) => ImageFilter.compose(
        outer: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        inner: const ColorFilter.matrix(saturate),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final circle = shape == BoxShape.circle;
    final br = circle ? null : BorderRadius.circular(radius);
    // iOS 27: kaca sedikit lebih pekat dan isi di belakangnya lebih tersebar, supaya teks di atas kaca terbaca.
    final double a = solid ? 1 : (clear ? (dark ? 0.20 : 0.26) : (dark ? 0.50 : 0.55));
    final fill = tint ?? (dark ? AppColors.navySurface.withValues(alpha: a) : Colors.white.withValues(alpha: a));

    Widget glass = DecoratedBox(
      decoration: BoxDecoration(color: fill, shape: shape, borderRadius: br),
      child: CustomPaint(
        foregroundPainter: GlassSheen(dark: dark || (tint != null && tint!.computeLuminance() < 0.5), radius: radius, circle: circle, solid: solid),
        child: Padding(padding: padding, child: child),
      ),
    );

    if (!solid && blur > 0) glass = BackdropFilter(filter: backdrop(blur * 1.25), child: glass);
    glass = circle ? ClipOval(child: glass) : ClipRRect(borderRadius: br!, child: glass);

    if (!shadow) return glass;
    final g = glow;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: br,
        boxShadow: [
          if (g != null) BoxShadow(color: g.withValues(alpha: dark ? 0.55 : 0.40), blurRadius: 22, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.32 : 0.09), blurRadius: 30, offset: const Offset(0, 14)),
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.18 : 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: glass,
    );
  }
}

/// Kilau kaca: pita pembiasan di tepi, kilau tepi, sorotan atas, kaustik bawah. Digambar di atas isi.
class GlassSheen extends CustomPainter {
  GlassSheen({required this.dark, required this.radius, this.circle = false, this.solid = false, this.strength = 1});
  final bool dark;
  final double radius;
  final bool circle;
  final bool solid;

  /// 0..1+ — kekuatan kilau (dipakai lensa navigasi yang "menyala" saat disentuh).
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = circle ? size.shortestSide / 2 : radius.clamp(0, size.shortestSide / 2).toDouble();
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
    final s = strength;

    if (solid) {
      canvas.drawRRect(
        rr.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = (dark ? Colors.white : AppColors.navy).withValues(alpha: 0.7),
      );
      return;
    }

    canvas.save();
    canvas.clipRRect(rr);

    // 1. pita pembiasan: tepi dalam lebar & lembut, lebih terang dari tengah (kaca tebal di tepi)
    final band = (size.shortestSide * 0.18).clamp(4.0, 14.0).toDouble();
    canvas.drawRRect(
      rr.deflate(band / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, band * 0.55)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: (dark ? 0.16 : 0.42) * s),
            Colors.white.withValues(alpha: (dark ? 0.03 : 0.08) * s),
            Colors.white.withValues(alpha: (dark ? 0.10 : 0.26) * s),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );

    // 2. sorotan specular: separuh atas sedikit lebih terang, memudar ke tengah
    final top = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: (dark ? 0.14 : 0.42) * s), Colors.white.withValues(alpha: 0)],
        ).createShader(top),
    );

    // 3. kaustik: garis cahaya tipis di dasar, seperti cahaya yang terkumpul setelah menembus kaca
    final cy = size.height - 1.5;
    canvas.drawLine(
      Offset(r * 0.9, cy),
      Offset(size.width - r * 0.9, cy),
      Paint()
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2)
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: (dark ? 0.22 : 0.55) * s),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromLTWH(0, cy - 2, size.width, 4)),
    );
    canvas.restore();

    // 0. tepi gelap tipis di sekeliling kaca (iOS 27): memberi kedalaman dan memisahkan kaca dari latar
    canvas.drawRRect(
      rr.deflate(0.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = Colors.black.withValues(alpha: dark ? 0.55 : 0.14),
    );

    // 4. kilau tepi: terang di kiri-atas, redup di tengah, menyala lagi tipis di kanan-bawah (pembiasan)
    canvas.drawRRect(
      rr.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: ((dark ? 0.78 : 1.0) * s).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (dark ? 0.08 : 0.25) * s),
            Colors.white.withValues(alpha: (dark ? 0.05 : 0.15) * s),
            Colors.white.withValues(alpha: ((dark ? 0.34 : 0.65) * s).clamp(0.0, 1.0)),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(rect),
    );

    // 5. garis gelap sangat tipis di sisi dalam bawah: memberi ketebalan kaca
    canvas.drawRRect(
      rr.deflate(1.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: dark ? 0.22 : 0.06)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(GlassSheen old) =>
      old.dark != dark || old.radius != radius || old.circle != circle || old.solid != solid || old.strength != strength;
}

/// Tekan pada kaca: menyusut 3 % dan sedikit lebih terang saat jari menyentuh (umpan balik di pointer-down),
/// kembali saat dilepas. Pegas teredam kritis lewat kurva ease-out kuat; mati saat "kurangi gerak".
class LiquidPress extends StatefulWidget {
  const LiquidPress({super.key, required this.child, this.onTap, this.scale = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<LiquidPress> createState() => _LiquidPressState();
}

class _LiquidPressState extends State<LiquidPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !still ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 120 : 200),
        curve: const Cubic(0.23, 1, 0.32, 1),
        child: AnimatedOpacity(
          opacity: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Tombol kaca (bulat atau kotak membulat) dengan lencana opsional. Saat ditekan kaca "menggembung"
/// sedikit (skala 1,06) dan kilaunya menguat — seperti tombol kaca iOS 26 — lalu kembali.
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 48,
    this.radius = 16,
    this.circle = false,
    this.tint,
    this.glow,
    this.clear = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final double size;
  final double radius;
  final bool circle;
  final Color? tint;
  final Color? glow;
  final bool clear;
  final String? semanticLabel;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = widget.circle ? null : BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          tapHaptic();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down && !still ? 1.06 : 1,
          duration: Duration(milliseconds: _down ? 140 : 260),
          curve: const Cubic(0.23, 1, 0.32, 1),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(fit: StackFit.expand, children: [
              LiquidGlass(
                radius: widget.radius,
                blur: 14,
                shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                tint: widget.tint,
                glow: widget.glow,
                clear: widget.clear,
                child: const SizedBox.expand(),
              ),
              // sorotan tambahan saat ditekan: kaca seolah menangkap lebih banyak cahaya
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _down ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: br,
                      gradient: RadialGradient(
                        center: const Alignment(-0.3, -0.5),
                        radius: 0.9,
                        colors: [Colors.white.withValues(alpha: dark ? 0.22 : 0.45), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Center(child: widget.child),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Header kaca yang menempel di atas daftar: bening di puncak, lalu berubah menjadi kaca cair
/// (blur + saturasi + kaustik di garis bawah) begitu isi digulir di bawahnya. Blur baru dipasang
/// setelah ada gulir (hemat tenaga di HP menengah).
class LiquidHeader extends StatelessWidget {
  const LiquidHeader({super.key, required this.controller, required this.child, this.blur = 22});
  final ScrollController controller;
  final Widget child;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final bg = theme.scaffoldBackgroundColor;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, c) {
        final off = controller.hasClients ? controller.offset : 0.0;
        final t = (off / 24).clamp(0.0, 1.0);
        final bar = DecoratedBox(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: (solid ? 1.0 : 0.62) * t),
            border: Border(
              bottom: BorderSide(color: (dark ? Colors.white : AppColors.navy).withValues(alpha: (dark ? 0.12 : 0.08) * t)),
            ),
          ),
          child: CustomPaint(
            // kaustik tipis di dasar header: tanda halus bahwa ini kaca, bukan pita warna
            foregroundPainter: _BottomCaustic(alpha: (dark ? 0.18 : 0.6) * t),
            child: c,
          ),
        );
        if (t == 0 || solid) return bar;
        return ClipRect(child: BackdropFilter(filter: LiquidGlass.backdrop(blur * t), child: bar));
      },
    );
  }
}

class _BottomCaustic extends CustomPainter {
  _BottomCaustic({required this.alpha});
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    final y = size.height - 1;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 1
        ..shader = LinearGradient(colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromLTWH(0, y - 1, size.width, 2)),
    );
  }

  @override
  bool shouldRepaint(_BottomCaustic old) => old.alpha != alpha;
}

/// Lembar bawah berbahan kaca cair (sudut atas membulat, pegangan kaca). Isi tetap terbaca karena
/// tint lebih pekat daripada kaca navigasi.
Future<T?> showLiquidSheet<T>(BuildContext context, {required WidgetBuilder builder, bool isScrollControlled = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (ctx) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: LiquidGlass(
          radius: 32,
          blur: 30,
          tint: (dark ? AppColors.navySurface : Colors.white).withValues(alpha: dark ? 0.78 : 0.82),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : AppColors.navy).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(child: builder(ctx)),
            ]),
          ),
        ),
      );
    },
  );
}
