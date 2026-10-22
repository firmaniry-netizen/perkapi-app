import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Gerak PERKAPI. Aturan: gerak hanya menjawab tindakan atau menandai perubahan status.
/// Semua widget di sini mati otomatis saat Reduce Motion aktif (MediaQuery.disableAnimations).
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Getaran halus untuk konfirmasi sentuhan (tombol utama, navigasi, ubin). Aman di web (diabaikan).
/// Sengaja dipanggil saat aksi dipilih, bukan saat jari menyentuh, agar menggulir daftar tidak bergetar.
void tapHaptic() {
  try {
    HapticFeedback.selectionClick();
  } catch (_) {}
}

/// Transisi halaman: masuk geser dari kanan + fade; halaman di bawahnya bergeser sedikit ke kiri (kedalaman).
class FadeThroughBuilder extends PageTransitionsBuilder {
  const FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final b = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOutCubic);
    // Halaman baru: geser dari kanan + membesar dari 0,96 + fade. Halaman lama: mundur kecil + redup.
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.82).animate(b),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.96).animate(b),
        child: FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(a),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(a),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Muncul bertahap: fade + naik. [index] mengatur jeda (maks. 8 langkah x 55 ms) agar daftar "mengalir".
/// Item dengan index > 9 langsung tampil (tidak mengulang saat di-scroll).
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.dy = 18});
  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context) || index > 9) return child;
    return _Delayed(
      delay: Duration(milliseconds: 55 * (index > 8 ? 8 : index)),
      builder: (go) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: go ? 1 : 0),
        duration: const Duration(milliseconds: 620),
        curve: const Cubic(0.16, 1, 0.3, 1),
        builder: (context, t, c) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: c),
        ),
        child: child,
      ),
    );
  }
}

/// Kerangka pemuat (skeleton) berdenyut lembut, pengganti spinner di daftar/dashboard.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 5, this.height = 84});
  final int count;
  final double height;
  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outline;
    return Semantics(
      label: 'Memuat',
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: widget.count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.28 + 0.30 * Curves.easeInOut.transform(_c.value)),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Umpan balik sentuhan: turun 2% selama 90 ms saat ditekan (menjawab aksi pengguna).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.98});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: (_down && !still) ? widget.scale : 1,
        duration: Duration(milliseconds: still ? 0 : (_down ? 100 : 340)),
        curve: _down ? Curves.easeOutCubic : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Muncul sekali: fade + skala 0,97 ke 1 (ease-out). Dipakai untuk satu momen orkestrasi di dashboard.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.duration = const Duration(milliseconds: 420)});
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.97 + 0.03 * t, child: c),
      ),
      child: child,
    );
  }
}

/// Angka menghitung naik sekali saat pertama tampil (setelah kartu anggota "terbit").
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
  });
  final int value;
  final TextStyle? style;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context) || value <= 0) return Text('$value', style: style);
    return _Delayed(
      delay: delay,
      builder: (go) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: go ? value.toDouble() : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('${v.round()}', style: style),
      ),
    );
  }
}

class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.builder});
  final Duration delay;
  final Widget Function(bool go) builder;
  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool _go = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _go = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _go = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_go);
}

/// Berdenyut dua kali lalu diam setiap kali [value] naik (mis. jumlah peringatan belum dibaca).
class PulseTwice extends StatefulWidget {
  const PulseTwice({super.key, required this.value, required this.child});
  final int value;
  final Widget child;
  @override
  State<PulseTwice> createState() => _PulseTwiceState();
}

class _PulseTwiceState extends State<PulseTwice> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
  ]).animate(_c);

  @override
  void initState() {
    super.initState();
    if (widget.value > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(PulseTwice old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) _play();
  }

  void _play() {
    if (!mounted || reduceMotion(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}


/// Kilau cahaya menyapu sekali melintasi [child] (mis. kartu anggota) setelah jeda singkat.
/// Dekoratif saja; mati saat Reduce Motion aktif.
class Sheen extends StatelessWidget {
  const Sheen({super.key, required this.child, this.delay = const Duration(milliseconds: 750)});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return _Delayed(
      delay: delay,
      builder: (go) => Stack(fit: StackFit.passthrough, children: [
        child,
        if (go)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeInOutCubic,
                builder: (context, t, _) => LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth;
                  return ClipRect(
                    child: Transform.translate(
                      offset: Offset(-w * 0.5 + t * w * 1.5, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: w * 0.26,
                            height: c.maxHeight * 1.7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
      ]),
    );
  }
}


/// Muncul "membal": skala 0,6 ke 1 (easeOutBack) + fade, berjenjang per [index] (35 ms).
/// Dipakai untuk ubin menu agar terasa hidup saat layar/menu dibuka. Mati saat Reduce Motion.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final i = index < 0 ? 0 : (index > 11 ? 11 : index);
    return _Delayed(
      delay: Duration(milliseconds: 80 + 35 * i),
      builder: (go) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: go ? 1 : 0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, t, c) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * t, child: c),
        ),
        child: child,
      ),
    );
  }
}

/// Getaran konfirmasi untuk keberhasilan penting (simpan, kirim). Aman di web (diabaikan).
void successHaptic() {
  try {
    HapticFeedback.mediumImpact();
  } catch (_) {}
}

/// Cincin cahaya yang "bernapas" pelan di belakang [child] (logo layar kunci / menunggu persetujuan).
/// Satu-satunya gerak berulang di aplikasi; menandai "sedang menunggu". Diam saat "kurangi gerak".
class BreathingRing extends StatefulWidget {
  const BreathingRing({super.key, required this.child, this.color = const Color(0xFFE8B53A), this.size = 132});
  final Widget child;
  final Color color;
  final double size;
  @override
  State<BreathingRing> createState() => _BreathingRingState();
}

class _BreathingRingState extends State<BreathingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(alignment: Alignment.center, children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final v = Curves.easeInOut.transform(_c.value);
              return Container(
                width: widget.size * (0.78 + 0.22 * v),
                height: widget.size * (0.78 + 0.22 * v),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color.withValues(alpha: 0.55 - 0.40 * v), width: 1.5),
                  gradient: RadialGradient(colors: [widget.color.withValues(alpha: 0.16 * (1 - v)), widget.color.withValues(alpha: 0)]),
                ),
              );
            },
          ),
        ),
        widget.child,
      ]),
    );
  }
}
