import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../constants/app_colors.dart';
import 'motion.dart';

/// Timbangan keadilan 3D asli (model GLB di assets/models/timbangan.glb).
/// Berputar otomatis, bisa diputar dengan geser jari. Memakai WebView, jadi sebaiknya hanya
/// dipasang di satu-dua halaman (bukan di daftar panjang). Di Android butuh
/// android:usesCleartextTraffic="true" (server lokal 127.0.0.1 milik paket).
class Scale3D extends StatelessWidget {
  const Scale3D({super.key, this.height = 280});
  final double height;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF091D40), AppColors.navy, Color(0xFF185898)]),
        ),
        child: Stack(children: [
          ModelViewer(
            src: 'assets/models/timbangan.glb',
            alt: 'Timbangan keadilan 3D',
            ar: false,
            autoRotate: !still,
            autoRotateDelay: 0,
            cameraControls: true,
            disableZoom: true,
            backgroundColor: Colors.transparent,
            environmentImage: 'neutral',
            exposure: 1.1,
            shadowIntensity: 0.8,
            cameraOrbit: '30deg 78deg auto',
          ),
          const Positioned(
            left: 16,
            bottom: 12,
            child: IgnorePointer(
              child: Text('Geser untuk memutar', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
