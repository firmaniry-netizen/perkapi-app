import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/motion_physics.dart';

class BurstAction {
  const BurstAction(this.label, this.icon, this.route, {this.color = AppColors.navyAction});
  final String label;
  final IconData icon;
  final String route;
  final Color color;
}

/// Menu aksi cepat yang "mekar" dari tombol merah di tengah navigasi.
///
/// Gerak:
/// - Latar: blur 0 -> 10 + tirai dongker 0 -> 62%, 420 ms ease-out.
/// - Gelembung: terbang dari pusat tombol ke posisi grid 3 kolom, skala 0,3 -> 1, berpegas (easeOutBack),
///   berjenjang 45 ms per item. Label muncul setelah gelembung mendarat.
/// - Tombol tengah berputar 45 derajat menjadi tanda tutup.
/// - Tutup: semua kembali ke pusat 260 ms (easeInCubic).
/// "Kurangi gerak": tanpa terbang/putar, hanya muncul.
///
/// Mengembalikan rute yang dipilih (atau null bila ditutup).
Future<String?> showActionBurst(BuildContext context, {required Offset origin, required List<BurstAction> actions}) {
  return Navigator.of(context).push<String>(PageRouteBuilder<String>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 620),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, anim, __) => _DragToClose(
      builder: (drag) => _ActionBurst(animation: anim, drag: drag, origin: origin, actions: actions),
    ),
  ));
}

/// Tarik ke bawah untuk menutup (pola gesture Reanimated: offset mengikuti jari, lepas = pegas atau tutup).
/// Lewat 110 px atau dikibas ke bawah (> 800 px/s) = tutup; selain itu kembali dengan pegas yang meneruskan kecepatan.
/// Tarik ke atas diberi efek karet (hanya 25% dari gerak jari).
class _DragToClose extends StatefulWidget {
  const _DragToClose({required this.builder});
  final Widget Function(Animation<double> drag) builder;
  @override
  State<_DragToClose> createState() => _DragToCloseState();
}

class _DragToCloseState extends State<_DragToClose> with SingleTickerProviderStateMixin {
  late final AnimationController _y = AnimationController.unbounded(vsync: this);
  double _raw = 0;
  bool _closing = false;

  @override
  void dispose() {
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {
        _y.stop();
        _raw = _y.value;
      },
      onVerticalDragUpdate: (d) {
        _raw += d.primaryDelta ?? 0;
        _y.value = _raw >= 0 ? _raw : _raw * 0.25;
      },
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (!_closing && (_y.value > 110 || v > 800)) {
          _closing = true;
          tapHaptic();
          Navigator.of(context).pop();
          return;
        }
        AppSpring.to(_y, 0, velocity: v, still: reduceMotion(context));
      },
      child: widget.builder(_y),
    );
  }
}

class _ActionBurst extends StatelessWidget {
  const _ActionBurst({required this.animation, required this.drag, required this.origin, required this.actions});
  final Animation<double> animation;

  /// Offset tarik-ke-bawah (px) dari _DragToClose.
  final Animation<double> drag;
  final Offset origin;
  final List<BurstAction> actions;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final size = MediaQuery.sizeOf(context);
    final ts = MediaQuery.textScalerOf(context);
    const cols = 3;
    final rows = (actions.length / cols).ceil();
    final gridW = math.min(size.width - 40, 380.0);
    final cellW = gridW / cols;
    final rowH = 92 + ts.scale(AppType.caption) * 2.4;
    final left = (size.width - gridW) / 2;
    final gridBottom = origin.dy - 52;

    Offset target(int i) {
      final r = i ~/ cols, c = i % cols;
      final inRow = math.min(cols, actions.length - r * cols); // baris terakhir yang tidak penuh diletakkan di tengah
      final rowLeft = left + (gridW - inRow * cellW) / 2;
      return Offset(rowLeft + c * cellW + cellW / 2, gridBottom - (rows - r) * rowH + rowH / 2);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([animation, drag]),
      builder: (context, _) {
        final reversing = animation.status == AnimationStatus.reverse;
        final base = still ? (animation.value > 0 ? 1.0 : 0.0) : animation.value;
        final dy = drag.value;
        // tirai menipis saat ditarik ke bawah: tanda bahwa melepas = menutup
        final fade = Curves.easeOut.transform(base.clamp(0.0, 1.0)) * (1 - (dy / 420).clamp(0.0, 0.6));
        return Stack(children: [
          // Tirai + blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10 * fade, sigmaY: 10 * fade),
                child: ColoredBox(color: AppColors.navyDeep.withValues(alpha: 0.62 * fade)),
              ),
            ),
          ),
          // Judul
          Positioned(
            left: left,
            right: left,
            top: gridBottom - rows * rowH - 44 + dy,
            child: Opacity(
              opacity: fade,
              child: Text('Aksi cepat', textAlign: TextAlign.center, style: AppType.headline(24, color: Colors.white)),
            ),
          ),
          // Gelembung aksi
          for (var i = 0; i < actions.length; i++)
            Builder(builder: (context) {
              final start = (i * 0.07).clamp(0.0, 0.5);
              final t = still
                  ? base
                  : reversing
                      ? Curves.easeInCubic.transform(base)
                      : Interval(start, math.min(1.0, start + 0.62), curve: Curves.easeOutBack).transform(base);
              final p = Offset.lerp(origin, target(i), t)! + Offset(0, dy);
              final labelOn = Interval(math.min(0.95, start + 0.45), 1, curve: Curves.easeOut).transform(base);
              return Positioned(
                left: p.dx - cellW / 2,
                top: p.dy - rowH / 2,
                width: cellW,
                height: rowH,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.3 + 0.7 * t,
                    child: _Bubble(
                      action: actions[i],
                      labelOpacity: still ? 1 : labelOn,
                      onTap: () {
                        tapHaptic();
                        Navigator.of(context).pop(actions[i].route);
                      },
                    ),
                  ),
                ),
              );
            }),
          // Tombol tutup menggantikan tombol merah (posisi sama), berputar 45 derajat
          Positioned(
            left: origin.dx - 26,
            top: origin.dy - 26,
            child: Semantics(
              button: true,
              label: 'Tutup aksi cepat',
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Transform.rotate(
                  angle: (still ? 1 : Curves.easeOutBack.transform(base.clamp(0.0, 1.0))) * math.pi / 4,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                      boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.45 * fade), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.action, required this.labelOpacity, required this.onTap});
  final BurstAction action;
  final double labelOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = action.color;
    return Semantics(
      button: true,
      label: action.label,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.tileGradient(c),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Icon(action.icon, color: Colors.white, size: 27),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: labelOpacity.clamp(0.0, 1.0),
              child: Text(action.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: AppType.caption, fontWeight: FontWeight.w700, height: 1.2)),
            ),
          ]),
        ),
      ),
    );
  }
}
