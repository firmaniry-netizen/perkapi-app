import 'package:flutter/material.dart';

/// Dulu memiringkan isi mengikuti kemiringan ponsel (akselerometer) dan geseran jari. Efek itu dibuang supaya
/// kartu diam seperti di iOS; [builder] kini selalu menerima kemiringan nol.
/// Kelas dan parameternya dipertahankan agar pemanggil tidak berubah.
class LiveTilt extends StatelessWidget {
  const LiveTilt({
    super.key,
    required this.builder,
    this.maxAngle = 0.20,
    this.useSensor = true,
    this.perspective = 0.0012,
  });

  final Widget Function(BuildContext context, Offset tilt) builder;
  final double maxAngle;
  final bool useSensor;
  final double perspective;

  @override
  Widget build(BuildContext context) => builder(context, Offset.zero);
}
