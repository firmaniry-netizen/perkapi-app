import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/perkapi_logo.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/illustrations.dart';
import '../welcome/welcome_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Urutan masuk: logo (0-55%) -> nama (35-80%) -> subjudul & progres (55-100%).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  // Cincin denyut lembut di belakang logo selama memuat.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  // Keluar: konten memudar + membesar sedikit, lingkaran warna latar melebar menutup layar.
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future<void>.delayed(const Duration(milliseconds: 2100), _next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ring.stop();
    } else if (!_ring.isAnimating) {
      _ring.repeat();
    }
  }

  Future<void> _next() async {
    if (!mounted) return;
    final router = GoRouter.of(context);
    final seen = await welcomeSeen();
    final target = SupabaseService.isLoggedIn
        ? AppRoutes.dashboard
        : (seen ? AppRoutes.login : AppRoutes.welcome); // sambutan hanya untuk pemasang baru yang belum login
    if (!mounted) return;
    if (!reduceMotion(context)) await _exit.forward();
    if (mounted) router.go(target);
  }

  @override
  void dispose() {
    _c.dispose();
    _ring.dispose();
    _exit.dispose();
    super.dispose();
  }

  Widget _rise(Animation<double> a, Widget child, {double dy = 14}) => FadeTransition(
        opacity: a,
        child: AnimatedBuilder(
          animation: a,
          builder: (_, c) => Transform.translate(offset: Offset(0, (1 - a.value) * dy), child: c),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final calm = reduceMotion(context);
    const logoSize = 104.0;

    final logo = SizedBox(
      width: logoSize * 1.9,
      height: logoSize * 1.9,
      child: Stack(alignment: Alignment.center, children: [
        if (!calm)
          AnimatedBuilder(
            animation: _ring,
            builder: (_, __) {
              final t = Curves.easeOut.transform(_ring.value);
              return Opacity(
                opacity: (1 - t) * 0.35,
                child: Container(
                  width: logoSize * (1 + 0.8 * t),
                  height: logoSize * (1 + 0.8 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              );
            },
          ),
        const PerkapiLogo(size: logoSize, onDark: true, animate: true),
      ]),
    );

    final name = const Wordmark(size: 36, color: Colors.white);
    final sub = Text(
      AppConstants.appSubtitle,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14),
    );
    final bar = SizedBox(
      width: 120,
      child: LinearProgressIndicator(
        minHeight: 3,
        borderRadius: BorderRadius.circular(3),
        color: AppColors.red,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
      ),
    );

    final logoA = _iv(0.0, 0.55, Curves.easeOutBack);
    final nameA = _iv(0.35, 0.80);
    final subA = _iv(0.55, 1.0);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          calm
              ? logo
              : FadeTransition(
                  opacity: _iv(0.0, 0.35),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.72, end: 1).animate(logoA),
                    child: logo,
                  ),
                ),
          const SizedBox(height: 4),
          calm ? name : _rise(nameA, name),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: subA,
            builder: (_, __) => Container(
              width: 56 * (calm ? 1 : subA.value),
              height: 3,
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 12),
          calm ? sub : _rise(subA, sub),
          const SizedBox(height: 32),
          calm ? bar : FadeTransition(opacity: subA, child: bar),
        ],
      ),
    );
    final revealColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: dark ? AppColors.navyDeep : AppColors.navy,
      body: AuroraBackground(
        child: Stack(children: [
          const Positioned.fill(child: DotGrid(opacity: 0.07)),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _exit,
                builder: (_, c) => Opacity(
                  opacity: 1 - Curves.easeIn.transform(_exit.value),
                  child: Transform.scale(scale: 1 + 0.10 * _exit.value, child: c),
                ),
                child: content,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _exit,
                builder: (_, __) => CustomPaint(painter: _RevealPainter(Curves.easeInOutCubic.transform(_exit.value), revealColor)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Lingkaran dari tengah layar yang melebar sampai menutup seluruh layar.
class _RevealPainter extends CustomPainter {
  _RevealPainter(this.t, this.color);
  final double t;
  final Color color;
  @override
  void paint(Canvas c, Size z) {
    if (t <= 0) return;
    final r = t * math.sqrt(z.width * z.width + z.height * z.height) / 2 * 1.05;
    c.drawCircle(z.center(Offset.zero), r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RevealPainter o) => o.t != t || o.color != color;
}
