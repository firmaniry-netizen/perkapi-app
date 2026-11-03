import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'liquid_glass.dart';
import 'motion.dart';

/// Overlay PERKAPI yang halus: kurva "expo-out" (cepat di awal, mendarat lembut), tutup lebih singkat
/// dari buka, scrim dongker. Mati (durasi 0) saat Reduce Motion aktif.
const Curve _land = Cubic(0.16, 1, 0.3, 1);
const Color _scrim = Color(0x99061230);

/// Pengganti showModalBottomSheet: naik 460 ms, turun 280 ms. Lembar berbahan kaca cair (iOS 26):
/// latar diburamkan + disaturasi, tint tembus pandang dari tema, kilau tepi, pegangan kaca.
Future<T?> showSmoothSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useSafeArea = false,
}) {
  final still = reduceMotion(context);
  return showModalBottomSheet<T>(
    context: context,
    builder: (ctx) => _GlassSheetFrame(handle: showDragHandle ?? true, child: builder(ctx)),
    isScrollControlled: isScrollControlled,
    showDragHandle: false,
    useSafeArea: useSafeArea,
    barrierColor: _scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: still ? Duration.zero : const Duration(milliseconds: 460),
      reverseDuration: still ? Duration.zero : const Duration(milliseconds: 280),
      curve: _land,
      reverseCurve: Curves.easeInCubic,
    ),
  );
}

/// Pengganti showDialog: fade + naik 4% + skala 0,92 ke 1 dengan kurva mendarat lembut (320 ms).
Future<T?> showSmoothDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final still = reduceMotion(context);
  final navContext = Navigator.of(context, rootNavigator: true).context;
  final themes = InheritedTheme.capture(from: context, to: navContext);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: _scrim,
    transitionDuration: still ? Duration.zero : const Duration(milliseconds: 320),
    pageBuilder: (ctx, _, __) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (ctx, anim, _, child) {
      final move = CurvedAnimation(parent: anim, curve: _land, reverseCurve: Curves.easeInCubic);
      // Kaca: layar di belakang dialog ikut diburamkan, makin kuat seiring dialog muncul.
      final glass = !MediaQuery.highContrastOf(ctx);
      Widget out = FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(move),
          child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1).animate(move), child: child),
        ),
      );
      if (glass) {
        out = AnimatedBuilder(
          animation: anim,
          child: out,
          builder: (_, c) {
            final v = anim.value.clamp(0.0, 1.0);
            return BackdropFilter(filter: ImageFilter.blur(sigmaX: 14 * v, sigmaY: 14 * v), child: c);
          },
        );
      }
      return out;
    },
  );
}

/// Bingkai lembar bawah kaca: blur + saturasi latar, kilau tepi, pegangan kaca. Warna isi tembus pandang
/// datang dari bottomSheetTheme (lihat theme.dart), jadi teks tetap terbaca.
class _GlassSheetFrame extends StatelessWidget {
  const _GlassSheetFrame({required this.child, required this.handle});
  final Widget child;
  final bool handle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    const r = BorderRadius.vertical(top: Radius.circular(32));
    Widget body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (handle)
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: (dark ? Colors.white : AppColors.navy).withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      Flexible(child: child),
    ]);
    body = CustomPaint(foregroundPainter: GlassSheen(dark: dark, radius: 32, solid: solid), child: body);
    if (solid) return body;
    return ClipRRect(borderRadius: r, child: BackdropFilter(filter: LiquidGlass.backdrop(30), child: body));
  }
}
