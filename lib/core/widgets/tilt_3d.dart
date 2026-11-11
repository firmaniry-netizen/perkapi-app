import 'package:flutter/material.dart';

/// Dulu memiringkan kartu mengikuti sentuhan dengan kilau cahaya. Efek itu dibuang supaya kartu diam seperti di iOS.
/// Kelas dan parameternya dipertahankan agar pemanggil tidak berubah.
class Tilt3D extends StatelessWidget {
  const Tilt3D({super.key, required this.child, this.maxAngle = 0.2, this.radius = 22, this.shine = true});
  final Widget child;
  final double maxAngle;
  final double radius;
  final bool shine;

  @override
  Widget build(BuildContext context) => child;
}
