import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/// Latar dongker dengan cahaya lembut yang bergerak pelan (aurora). Ringan: hanya 3 gradien radial.
/// Statis bila Reduce Motion aktif.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: AppColors.navyDeep),
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _AuroraPainter(_c.value)),
        ),
      ),
      widget.child,
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    void blob(double fx, double fy, double ph, double r, Color color) {
      final c = Offset(
        size.width * (0.5 + fx * math.sin(a + ph)),
        size.height * (0.5 + fy * math.cos(a * 0.8 + ph)),
      );
      final radius = size.shortestSide * r;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    blob(0.35, 0.30, 0.0, 0.95, const Color(0xFF2456B8).withValues(alpha: 0.55));
    blob(0.40, 0.35, 2.1, 0.80, AppColors.red.withValues(alpha: 0.22));
    blob(0.30, 0.40, 4.2, 0.85, const Color(0xFF16397A).withValues(alpha: 0.70));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
