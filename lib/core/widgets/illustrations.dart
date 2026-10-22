import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/art_3d.dart';

/// Ilustrasi digambar lewat kode (tanpa aset/paket tambahan) dalam palet dongker, merah, putih.

/// Timbangan keadilan bergaya garis, putih di atas dongker, dengan satu titik merah di puncak.
class ScalesArt extends StatelessWidget {
  const ScalesArt({super.key, this.size = 140, this.opacity = 1});
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(size: Size.square(size), painter: _ScalesPainter(opacity)));
}

class _ScalesPainter extends CustomPainter {
  _ScalesPainter(this.o);
  final double o;
  @override
  void paint(Canvas c, Size z) {
    final s = z.width;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * o)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.028;
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * o)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.014;
    c.drawLine(Offset(s * .5, s * .2), Offset(s * .5, s * .88), line);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(s * .3, s * .88, s * .7, s * .94), Radius.circular(s * .03)),
        Paint()..color = Colors.white.withValues(alpha: 0.9 * o));
    c.drawLine(Offset(s * .14, s * .28), Offset(s * .86, s * .28), line);
    for (final x in [s * .14, s * .86]) {
      c.drawLine(Offset(x, s * .28), Offset(x - s * .11, s * .56), thin);
      c.drawLine(Offset(x, s * .28), Offset(x + s * .11, s * .56), thin);
      final pan = Path()
        ..moveTo(x - s * .14, s * .56)
        ..quadraticBezierTo(x, s * .74, x + s * .14, s * .56)
        ..close();
      c.drawPath(
        pan,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.95 * o), Colors.white.withValues(alpha: 0.45 * o)],
          ).createShader(Rect.fromLTWH(x - s * .14, s * .56, s * .28, s * .18)),
      );
    }
    c.drawCircle(Offset(s * .5, s * .15), s * .055, Paint()..color = AppColors.red.withValues(alpha: o));
  }

  @override
  bool shouldRepaint(_ScalesPainter old) => old.o != o;
}

/// Pola titik halus untuk latar kepala layar (memberi tekstur, bukan datar).
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, this.opacity = 0.10});
  final double opacity;
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(painter: _DotPainter(opacity), size: Size.infinite));
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.o);
  final double o;
  @override
  void paint(Canvas c, Size z) {
    final p = Paint()..color = Colors.white.withValues(alpha: o);
    for (double y = 10; y < z.height; y += 14) {
      for (double x = 10; x < z.width; x += 14) {
        c.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.o != o;
}

/// Tumpukan tiga foto miring (matahari merah, gunung dongker). Dipakai untuk banner Galeri.
class PhotoStackArt extends StatelessWidget {
  const PhotoStackArt({super.key, this.size = 120});
  final double size;
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(size: Size.square(size), painter: _PhotoStackPainter()));
}

class _PhotoStackPainter extends CustomPainter {
  void _photo(Canvas c, Offset ctr, double w, double h, double angle, List<Color> sky) {
    c.save();
    c.translate(ctr.dx, ctr.dy);
    c.rotate(angle);
    final frame = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(w * .1));
    c.drawShadow(Path()..addRRect(frame), const Color(0xFF020A1C), 8, true);
    c.drawRRect(frame, Paint()..color = Colors.white);
    final inner = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -h * .04), width: w * .86, height: h * .76), Radius.circular(w * .07));
    c.drawRRect(
      inner,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky)
            .createShader(inner.outerRect),
    );
    c.save();
    c.clipRRect(inner);
    final r = inner.outerRect;
    c.drawCircle(Offset(r.right - w * .2, r.top + h * .16), w * .075, Paint()..color = AppColors.red);
    c.drawPath(
      Path()
        ..moveTo(r.left, r.bottom)
        ..lineTo(r.left + r.width * .34, r.top + r.height * .42)
        ..lineTo(r.left + r.width * .56, r.top + r.height * .68)
        ..lineTo(r.left + r.width * .74, r.top + r.height * .5)
        ..lineTo(r.right, r.bottom)
        ..close(),
      Paint()..color = AppColors.navy,
    );
    c.restore();
    c.restore();
  }

  @override
  void paint(Canvas c, Size z) {
    final s = z.width;
    _photo(c, Offset(s * .36, s * .5), s * .54, s * .66, -0.2, const [Color(0xFF7FB2F0), Color(0xFFBFD8F7)]);
    _photo(c, Offset(s * .64, s * .5), s * .54, s * .66, 0.17, const [Color(0xFF3F7BD1), Color(0xFF9CC3F2)]);
    _photo(c, Offset(s * .5, s * .56), s * .56, s * .68, -0.02, const [Color(0xFF1E5CC0), Color(0xFF7FB2F0)]);
  }

  @override
  bool shouldRepaint(_PhotoStackPainter old) => false;
}

/// Ilustrasi keadaan kosong: dua kartu miring (merah lembut, biru lembut) + gambar 3D bila ada,
/// selain itu lingkaran dongker berisi ikon.
class EmptyArt extends StatelessWidget {
  const EmptyArt({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget card(double angle, Offset off, Color c) => Transform.translate(
          offset: off,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 84,
              height: 100,
              decoration: BoxDecoration(
                color: c.withValues(alpha: dark ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: c.withValues(alpha: 0.30)),
              ),
            ),
          ),
        );
    return SizedBox(
      width: 150,
      height: 124,
      child: Stack(alignment: Alignment.center, children: [
        card(-math.pi / 11, const Offset(-30, 4), AppColors.red),
        card(math.pi / 12, const Offset(30, 2), AppColors.sky),
        if (Art3D.forIcon(icon) case final art?)
          Image.asset(art, width: 118, height: 118, fit: BoxFit.contain, cacheWidth: 354)
        else
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2456B8), AppColors.navy],
            ),
            boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Icon(icon, color: Colors.white, size: 38),
        ),
      ]),
    );
  }
}
