import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import 'motion.dart';

/// Logo resmi PERKAPI (sama dengan situs: segi enam, tiga sosok, jabat tangan, buku emas) di atas
/// ubin putih membulat — logo ini dirancang untuk latar putih, jadi tetap terbaca di latar dongker.
/// Gambar sumber 1024 px (`images/logo_perkapi.png`), tajam sampai ukuran ubin ±300 dp.
/// Bila [animate] aktif: ubin muncul membesar halus lalu kilau tipis menyapu sekali.
class PerkapiMark extends StatelessWidget {
  const PerkapiMark({super.key, this.size = 96, this.animate = false});

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final go = animate && !reduceMotion(context);
    return Semantics(
      label: 'Logo PERKAPI',
      image: true,
      child: go
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.linear,
              builder: (_, t, __) => _tile(t),
            )
          : _tile(1),
    );
  }

  Widget _tile(double t) {
    // 0..0.45: masuk (skala 0,86 -> 1, pudar); 0.45..1: kilau menyapu
    final enter = const Cubic(0.2, 0, 0, 1).transform((t / 0.45).clamp(0.0, 1.0));
    final shine = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    final r = BorderRadius.circular(size * 0.24);
    return Opacity(
      opacity: enter,
      child: Transform.scale(
        scale: 0.86 + 0.14 * enter,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: r,
            boxShadow: [
              BoxShadow(color: const Color(0xFF020818).withValues(alpha: 0.28), blurRadius: size * 0.22, offset: Offset(0, size * 0.08)),
            ],
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Stack(fit: StackFit.expand, children: [
              Padding(
                padding: EdgeInsets.all(size * 0.10),
                child: Image.asset(
                  AppAssets.logoPerkapi,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: (size * 3).clamp(64, 1024).toInt(),
                ),
              ),
              if (shine > 0 && shine < 1)
                IgnorePointer(
                  child: FractionalTranslation(
                    translation: Offset(-1.2 + 2.4 * shine, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
