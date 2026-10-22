import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Fisika gerak bersama untuk interaksi jari (padanan konstanta SPRING/TIMING di Reanimated).
/// Pegas diredam kritis: tidak memantul (bounce 0), sesuai karakter PERKAPI yang tenang & tegas.
class AppSpring {
  AppSpring._();

  /// Kembali ke posisi semula setelah digeser (baris geser, kartu, menu).
  static const snap = SpringDescription(mass: 1, stiffness: 260, damping: 32);

  /// Benda besar yang berputar/berpindah jauh (balik kartu anggota): sedikit lebih lambat.
  static const heavy = SpringDescription(mass: 1, stiffness: 170, damping: 26);

  /// Animasikan [c] ke [target] dengan pegas, meneruskan kecepatan jari ([velocity], satuan nilai/detik).
  /// [still] = "kurangi gerak": langsung lompat ke target tanpa gerak.
  static TickerFuture to(AnimationController c, double target,
      {double velocity = 0, SpringDescription spring = snap, bool still = false}) {
    if (still) {
      c.value = target;
      return TickerFuture.complete();
    }
    return c.animateWith(SpringSimulation(spring, c.value, target, velocity));
  }
}
