import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/live_tilt.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/perkapi_mark.dart';

/// Kartu anggota 3D di Beranda: satu-satunya titik fokus layar.
///
/// Gerak (semua mati pada "kurangi gerak"):
/// - Masuk: kartu "berdiri" dari miring ke depan (rotateX 0,55 rad -> 0) + fade, 900 ms, ease-out kuat. Sekali.
/// - Hidup: miring mengikuti kemiringan HP / geseran jari (LiveTilt, maks. 0,16 rad).
/// - Kedalaman: logo, cip, dan teks bergeser berlawanan arah dengan kemiringan pada jarak berbeda (paralaks 3 lapis).
/// - Foil hologram emas-biru bergeser mengikuti kemiringan; sorot cahaya mengikuti arah miring; bayangan menjauh.
/// Ketuk -> halaman Kartu Anggota (QR).
class MemberHeroCard extends StatelessWidget {
  const MemberHeroCard({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final card = Semantics(
      button: true,
      label: 'Kartu anggota. Ketuk untuk menampilkan QR.',
      child: GestureDetector(
        onTap: () {
          tapHaptic();
          onOpen();
        },
        child: AspectRatio(
          aspectRatio: 1.62,
          child: LiveTilt(maxAngle: 0.16, builder: (context, t) => _CardFace(t: t)),
        ),
      ),
    );
    if (still) return card;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: AppMotion.emphasized,
      child: card,
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 24),
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014)
              ..rotateX((1 - v) * 0.55),
            child: c,
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.t});
  final Offset t;

  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    final m = a.member ?? const {};
    final status = '${m['status'] ?? '-'}';
    final active = status == 'Aktif';
    final verified = m['ahu_verified'] == true;
    final r = BorderRadius.circular(AppRadius.hero);
    // Paralaks: lapisan dekat bergeser lebih jauh dari lapisan latar.
    Offset px(double depth) => Offset(-t.dx * depth, -t.dy * depth);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: AppColors.navyDeep.withValues(alpha: 0.42),
            blurRadius: 34,
            spreadRadius: -6,
            offset: Offset(t.dx * 14, 20 + t.dy * 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(fit: StackFit.expand, children: [
          // 1) Dasar dongker tiga nada
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A1735), AppColors.navy, Color(0xFF1B3F9A)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          // 2) Pola guilloche (seperti cetakan dokumen berharga): latar, paralaks paling kecil
          Transform.translate(
            offset: px(3),
            child: const RepaintBoundary(child: CustomPaint(painter: _GuillochePainter())),
          ),
          // 3) Logo PERKAPI besar samar (siluet putih) di kanan bawah, seperti cap air dokumen resmi
          Positioned(
            right: -30 + px(8).dx,
            bottom: -34 + px(8).dy,
            child: RepaintBoundary(
              child: Opacity(
                opacity: 0.09,
                child: Image.asset(AppAssets.logoPerkapi, width: 210, color: Colors.white, colorBlendMode: BlendMode.srcIn, cacheWidth: 630),
              ),
            ),
          ),
          // 4) Foil hologram: pita emas-biru yang bergeser mengikuti kemiringan
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.2 + t.dx * 0.9, -1 + t.dy * 0.6),
                  end: Alignment(1.2 + t.dx * 0.9, 1 + t.dy * 0.6),
                  colors: [
                    Colors.transparent,
                    AppColors.gold.withValues(alpha: 0.10 + 0.10 * t.distance.clamp(0.0, 1.0)),
                    const Color(0xFF8FBAFF).withValues(alpha: 0.08 + 0.08 * t.distance.clamp(0.0, 1.0)),
                    Colors.transparent,
                  ],
                  stops: const [0.30, 0.46, 0.56, 0.72],
                ),
              ),
            ),
          ),
          // 5) Isi kartu (paralaks terbesar = paling "dekat")
          Transform.translate(
            offset: px(6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const PerkapiMark(size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('PERKAPI', style: AppType.headline(16, color: Colors.white).copyWith(letterSpacing: 1.4)),
                      Text('KARTU ANGGOTA DIGITAL',
                          style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.95),
                              fontSize: AppType.micro,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3)),
                    ]),
                  ),
                  const _Chip(),
                ]),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    a.name,
                    maxLines: 1,
                    style: AppType.headline(23, color: Colors.white, height: 1.1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No. ${m['member_number'] ?? '-'}',
                  style: AppType.headline(15, color: AppColors.gold, weight: FontWeight.w700).copyWith(letterSpacing: 1.6, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _Pill(text: status, dot: active ? const Color(0xFF5CE08A) : const Color(0xFFFFB74D)),
                  const SizedBox(width: 6),
                  if (verified) ...[
                    const _Pill(text: 'AHU', icon: Icons.verified_rounded),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: _Pill(text: a.roleLabel)),
                  const SizedBox(width: 8),
                  const Spacer(),
                  const _QrBadge(),
                ]),
              ]),
            ),
          ),
          // 6) Sorot cahaya mengikuti arah miring (paling atas, tidak menangkap sentuhan)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(t.dx * 0.9, t.dy * 0.9 - 0.4),
                  radius: 1.0,
                  colors: [Colors.white.withValues(alpha: 0.06 + 0.12 * t.distance.clamp(0.0, 1.0)), Colors.transparent],
                ),
              ),
            ),
          ),
          // 7) Garis emas tipis di tepi atas + strip segel merah pendek
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.gold.withValues(alpha: 0),
                  AppColors.gold.withValues(alpha: 0.85),
                  AppColors.gold.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          const Positioned(
            left: 20,
            bottom: 0,
            width: 44,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Cip emas seperti kartu fisik (digambar, bukan gambar).
class _Chip extends StatelessWidget {
  const _Chip();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 40,
        height: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.goldHi, AppColors.gold, Color(0xFFB8860B)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: const CustomPaint(painter: _ChipLines()),
        ),
      );
}

class _ChipLines extends CustomPainter {
  const _ChipLines();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = const Color(0xFF7A5A08).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.32, s.height * 0.22, s.width * 0.36, s.height * 0.56), const Radius.circular(3));
    canvas.drawRRect(r, p);
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width * 0.32, s.height / 2), p);
    canvas.drawLine(Offset(s.width * 0.68, s.height / 2), Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height * 0.22), p);
    canvas.drawLine(Offset(s.width / 2, s.height * 0.78), Offset(s.width / 2, s.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pola garis gelombang halus berlapis (guilloche). Statis: digambar sekali lalu di-cache (RepaintBoundary).
class _GuillochePainter extends CustomPainter {
  const _GuillochePainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.055);
    for (var k = 0; k < 16; k++) {
      final path = Path();
      final amp = s.height * (0.10 + 0.018 * k);
      final phase = k * 0.42;
      for (var x = 0.0; x <= s.width; x += 4) {
        final y = s.height * 0.62 + math.sin(x / s.width * math.pi * 2.6 + phase) * amp * math.cos(x / s.width * math.pi * 0.7);
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.dot, this.icon});
  final String text;
  final Color? dot;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.gold),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: AppType.caption, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _QrBadge extends StatelessWidget {
  const _QrBadge();
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy, size: 24),
      );
}
