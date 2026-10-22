import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../constants/app_colors.dart';
import 'motion.dart';
import 'motion_physics.dart';

/// Aksi yang muncul di belakang baris saat digeser.
class SwipeAction {
  const SwipeAction({required this.label, required this.icon, required this.color, required this.onCommit, this.removes = false});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onCommit;

  /// true: baris keluar dari layar (mis. diarsipkan) sebelum [onCommit]. false: aksi dijalankan lalu baris kembali.
  final bool removes;
}

/// Baris yang bisa digeser ke samping untuk aksi cepat — pola "swipeable row" Reanimated + gesture-handler,
/// dibuat dengan alat bawaan Flutter:
/// - Geser HANYA horizontal: pengenal drag horizontal Flutter kalah otomatis bila jari bergerak vertikal,
///   jadi daftar tetap bisa digulir (padanan activeOffsetX + failOffsetY).
/// - Pola offset: posisi awal disimpan saat jari menyentuh, lalu ditambah pergeseran (geser berikutnya tidak melompat).
/// - Lepas: lewat ambang (32% lebar) atau dikibas (> 900 px/s) = aksi; selain itu kembali dengan pegas yang
///   meneruskan kecepatan jari. Getaran halus sekali saat melewati ambang, ikon aksi membesar 0,25 -> 1.
/// - Pembaca layar: aksi juga tersedia sebagai aksi aksesibilitas (tanpa perlu menggeser).
class SwipeRow extends StatefulWidget {
  const SwipeRow({super.key, required this.child, this.startAction, this.endAction, this.radius = 20});
  final Widget child;

  /// Digeser ke kanan.
  final SwipeAction? startAction;

  /// Digeser ke kiri.
  final SwipeAction? endAction;
  final double radius;

  @override
  State<SwipeRow> createState() => _SwipeRowState();
}

class _SwipeRowState extends State<SwipeRow> with SingleTickerProviderStateMixin {
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  double _width = 1;
  bool _armed = false;

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  SwipeAction? get _active => _x.value > 0 ? widget.startAction : (_x.value < 0 ? widget.endAction : null);

  void _start(DragStartDetails _) => _x.stop();

  void _update(DragUpdateDetails d) {
    var next = _x.value + (d.primaryDelta ?? 0);
    if (widget.startAction == null && next > 0) next = 0;
    if (widget.endAction == null && next < 0) next = 0;
    // lewat 45% lebar: perlambat (karet), supaya terasa ada batas
    final lim = _width * 0.45;
    if (next.abs() > lim) next = next.sign * (lim + (next.abs() - lim) * 0.35);
    _x.value = next;
    final armed = next.abs() > _width * 0.32;
    if (armed != _armed) {
      setState(() => _armed = armed);
      if (armed) HapticFeedback.selectionClick();
    }
  }

  Future<void> _end(DragEndDetails d) async {
    final still = reduceMotion(context);
    final v = d.primaryVelocity ?? 0;
    final action = _active;
    final flick = v.abs() > 900 && v.sign == _x.value.sign && _x.value.abs() > 24;
    if (action != null && (_armed || flick)) {
      if (action.removes) {
        // keluar searah geseran (ease-in, lebih singkat dari masuk), lalu jalankan aksi
        final target = _x.value.sign * (_width + 24);
        if (still) {
          _x.value = target;
        } else {
          await _x.animateTo(target, duration: const Duration(milliseconds: 160), curve: Curves.easeIn);
        }
        action.onCommit();
        return;
      }
      tapHaptic();
      action.onCommit();
    }
    if (mounted) setState(() => _armed = false);
    AppSpring.to(_x, 0, velocity: v, still: still);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.startAction, e = widget.endAction;
    if (s == null && e == null) return widget.child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      customSemanticsActions: {
        if (s != null) CustomSemanticsAction(label: s.label): s.onCommit,
        if (e != null) CustomSemanticsAction(label: e.label): e.onCommit,
      },
      child: LayoutBuilder(builder: (context, c) {
        _width = c.maxWidth <= 0 ? 1 : c.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          child: AnimatedBuilder(
            animation: _x,
            child: widget.child,
            builder: (context, child) {
              final x = _x.value, a = _active;
              return Stack(children: [
                if (a != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(borderRadius: r, color: AppColors.soft(a.color, dark: dark)),
                      child: Align(
                        alignment: x > 0 ? Alignment.centerLeft : Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: _ActionMark(action: a, armed: _armed, dark: dark),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(offset: Offset(x, 0), child: child),
              ]);
            },
          ),
        );
      }),
    );
  }
}

/// Ikon + label aksi: silang-pudar skala 0,25 -> 1 saat ambang tercapai (tanpa pantulan).
class _ActionMark extends StatelessWidget {
  const _ActionMark({required this.action, required this.armed, required this.dark});
  final SwipeAction action;
  final bool armed, dark;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onSoft(action.color, dark: dark);
    const curve = Cubic(0.2, 0, 0, 1);
    const d = Duration(milliseconds: 220);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedScale(
        scale: armed ? 1 : 0.25,
        duration: d,
        curve: curve,
        child: AnimatedOpacity(
          opacity: armed ? 1 : 0.35,
          duration: d,
          curve: curve,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: action.color, shape: BoxShape.circle),
            child: Icon(action.icon, color: Colors.white, size: 22),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(action.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    ]);
  }
}
