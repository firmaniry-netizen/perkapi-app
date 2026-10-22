import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sensors_plus/sensors_plus.dart';

import 'motion.dart';

/// Kemiringan 3D "hidup": mengikuti kemiringan ponsel (akselerometer) dan geseran jari.
///
/// Hemat baterai & mulus:
/// - Gambar ulang hanya saat arah berubah (ticker berhenti sendiri ketika sudah diam).
/// - Ticker otomatis bisu saat halaman tertutup halaman lain (TickerMode), sensor dilepas saat aplikasi di latar.
/// - Posisi pegang dianggap netral dan pelan-pelan disesuaikan, jadi kartu kembali lurus bila HP dipegang lain.
/// - Mati total saat pengguna mengaktifkan "kurangi gerak".
///
/// [builder] menerima nilai kemiringan -1..1 (x: kiri-kanan, y: atas-bawah) untuk membuat kilau/lapisan paralaks.
class LiveTilt extends StatefulWidget {
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
  State<LiveTilt> createState() => _LiveTiltState();
}

class _LiveTiltState extends State<LiveTilt> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<AccelerometerEvent>? _sub;
  Offset _target = Offset.zero;
  Offset _cur = Offset.zero;
  Offset? _base;
  bool _drag = false;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = reduceMotion(context);
    if (still != _still || (_sub == null && !still)) {
      _still = still;
      still ? _stopSensor() : _startSensor();
      if (still) {
        _target = Offset.zero;
        _cur = Offset.zero;
      }
    }
  }

  void _startSensor() {
    if (_sub != null || kIsWeb || !widget.useSensor || _still) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(_onAccel, onError: (_) {});
    } catch (_) {}
  }

  void _stopSensor() {
    _sub?.cancel();
    _sub = null;
    _base = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSensor();
    } else {
      _stopSensor();
    }
  }

  void _onAccel(AccelerometerEvent e) {
    if (_drag) return;
    final raw = Offset(e.x, e.y);
    _base = _base == null ? raw : Offset.lerp(_base, raw, 0.004); // netral mengikuti cara pegang, sangat pelan
    final t = Offset(
      (-(e.x - _base!.dx) / 4).clamp(-1.0, 1.0),
      ((e.y - _base!.dy) / 4).clamp(-1.0, 1.0),
    );
    if ((t - _target).distance < 0.015) return; // zona mati: getaran tangan tidak memicu gambar ulang
    _target = t;
    _kick();
  }

  void _kick() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    final next = Offset.lerp(_cur, _target, _drag ? 0.35 : 0.12)!;
    if ((next - _target).distance < 0.002) {
      setState(() => _cur = _target);
      _ticker.stop();
      return;
    }
    setState(() => _cur = next);
  }

  void _pointer(PointerEvent e) {
    if (_still) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final s = box.size;
    _drag = true;
    _target = Offset(
      (e.localPosition.dx / s.width * 2 - 1).clamp(-1.0, 1.0),
      (e.localPosition.dy / s.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _kick();
  }

  void _release(PointerEvent _) {
    _drag = false;
    _target = Offset.zero;
    _kick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSensor();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _still ? Offset.zero : _cur;
    final m = Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..rotateX(-t.dy * widget.maxAngle)
      ..rotateY(t.dx * widget.maxAngle);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _pointer,
      onPointerMove: _pointer,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: RepaintBoundary(
        child: Transform(alignment: Alignment.center, transform: m, child: widget.builder(context, t)),
      ),
    );
  }
}
