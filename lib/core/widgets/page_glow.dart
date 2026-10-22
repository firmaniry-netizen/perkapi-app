import 'package:flutter/material.dart';

import 'motion.dart';

/// Cahaya radial berwarna aksen di belakang bagian atas halaman (di bawah AppBar), muncul halus 0,8 detik.
/// Memberi tiap layar warna sendiri tanpa menambah elemen. Dibungkus di `body:` Scaffold; konten tidak berubah ukuran.
/// Reduce Motion aktif: langsung tampil tanpa animasi.
class PageGlow extends StatelessWidget {
  const PageGlow({super.key, required this.accent, required this.child, this.height = 340});
  final Color accent;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glow = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.9, -1.0),
            radius: 1.1,
            colors: [accent.withValues(alpha: dark ? 0.22 : 0.14), accent.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    return Stack(children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: height,
        child: reduceMotion(context)
            ? glow
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                child: glow,
                builder: (_, v, c) => Opacity(opacity: v, child: c),
              ),
      ),
      Positioned.fill(child: child),
    ]);
  }
}
