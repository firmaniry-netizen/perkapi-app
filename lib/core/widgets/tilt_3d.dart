import 'package:flutter/material.dart';

import 'motion.dart';

/// Efek 3D: kartu miring mengikuti sentuhan/kursor (perspektif nyata) dengan kilau cahaya.
/// Memakai Listener, jadi tidak mengambil alih ketukan maupun scroll. Mati otomatis bila
/// pengguna mematikan animasi di perangkat.
class Tilt3D extends StatefulWidget {
  const Tilt3D({super.key, required this.child, this.maxAngle = 0.2, this.radius = 22, this.shine = true});
  final Widget child;
  final double maxAngle;
  final double radius;
  final bool shine;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> {
  Offset _t = Offset.zero; // -1..1 dari pusat
  bool _drag = false;

  void _move(PointerEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final s = box.size;
    setState(() {
      _drag = true;
      _t = Offset(
        (e.localPosition.dx / s.width * 2 - 1).clamp(-1.0, 1.0),
        (e.localPosition.dy / s.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _reset(PointerEvent _) => setState(() {
        _drag = false;
        _t = Offset.zero;
      });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _move,
      onPointerMove: _move,
      onPointerUp: _reset,
      onPointerCancel: _reset,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(end: _t),
        duration: _drag ? Duration.zero : const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, v, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..rotateX(-v.dy * widget.maxAngle)
            ..rotateY(v.dx * widget.maxAngle);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: Stack(children: [
              child!,
              if (widget.shine)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.radius),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(v.dx, v.dy),
                            radius: 0.9,
                            colors: [Colors.white.withOpacity(0.16 * (v.distance.clamp(0.0, 1.0))), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
        child: widget.child,
      ),
    );
  }
}
