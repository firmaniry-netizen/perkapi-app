import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/// Foto latar di bawah konten (login, kartu anggota, kepala layar).
///
/// - Foto muncul halus: fade + zoom-out 1,07 -> 1 selama 900 ms (satu kali, bukan loop).
/// - Bayangan dongker bergradasi di atas foto menjaga teks putih tetap terbaca (kontras tinggi).
/// - Bila file foto belum ada / gagal dimuat, widget ini TIDAK menggambar apa pun,
///   sehingga tampilan kembali ke latar dongker biasa (tidak ada kotak rusak).
/// - Reduce Motion aktif: foto langsung tampil tanpa animasi.
class PhotoBackdrop extends StatelessWidget {
  const PhotoBackdrop({super.key, required this.asset, this.shade = 0.74, this.cacheWidth = 1080});
  final String asset;

  /// Kepekatan bayangan dongker di bagian bawah foto (0 s.d. 1).
  final double shade;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return ClipRect(
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        errorBuilder: (_, e, __) {
          if (kDebugMode) {
            debugPrint('PhotoBackdrop: gagal memuat "$asset". Pastikan file ada di folder images/ dan terdaftar di '
                'pubspec.yaml, lalu JALANKAN ULANG aplikasi (hot reload tidak memuat aset baru). Detail: $e');
          }
          return const SizedBox.shrink();
        },
        frameBuilder: (ctx, child, frame, sync) {
          if (frame == null && !sync) return const SizedBox.shrink();
          final shaded = Stack(fit: StackFit.expand, children: [
            child,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navyDeep.withValues(alpha: shade * 0.55),
                    AppColors.navy.withValues(alpha: shade),
                  ],
                ),
              ),
            ),
          ]);
          if (still) return shaded;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            child: shaded,
            builder: (_, v, c) => Opacity(opacity: v, child: Transform.scale(scale: 1.07 - 0.07 * v, child: c)),
          );
        },
      ),
    );
  }
}
