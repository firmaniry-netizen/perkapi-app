import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/motion_physics.dart';
import '../../core/widgets/perkapi_logo.dart';
import '../ahu/ahu_page.dart';

/// Kartu anggota digital 3D. Miring mengikuti kemiringan ponsel (akselerometer) atau geseran jari,
/// dengan kilau cahaya yang bergerak. Ketuk untuk membalik: sisi belakang berisi QR.
/// QR hanya berisi token acak (bukan data pribadi); token diverifikasi backend lewat RPC verify_member_qr.
class MemberCardPage extends StatefulWidget {
  const MemberCardPage({super.key});
  @override
  State<MemberCardPage> createState() => _MemberCardPageState();
}

class _MemberCardPageState extends State<MemberCardPage> with SingleTickerProviderStateMixin {
  /// Ubah ke 1.0 bila arah miring terasa terbalik di perangkat Anda.
  static const double _sensorSign = -1.0;

  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero); // -1..1
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  StreamSubscription<AccelerometerEvent>? _sub;
  Offset _smooth = Offset.zero;
  Offset? _base;
  bool _dragging = false;
  bool _back = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(_onAccel, onError: (_) {});
      } catch (_) {}
    }
  }

  void _onAccel(AccelerometerEvent e) {
    if (_dragging) return;
    _base ??= Offset(e.x, e.y); // posisi pegang pertama dianggap netral
    final tx = (_sensorSign * (e.x - _base!.dx) / 5).clamp(-1.0, 1.0);
    final ty = ((e.y - _base!.dy) / 5).clamp(-1.0, 1.0);
    _smooth = Offset.lerp(_smooth, Offset(tx, ty), 0.14)!;
    _tilt.value = _smooth;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flip.dispose();
    _tilt.dispose();
    super.dispose();
  }

  void _toggle() {
    tapHaptic();
    _back = !_back;
    AppSpring.to(_flip, _back ? 1 : 0, spring: AppSpring.heavy, still: reduceMotion(context));
  }

  // ---- balik dengan jari (pola Reanimated: offset + pegas yang meneruskan kecepatan) ----
  // Geser ke kiri membalik ke sisi QR, ke kanan kembali. Kartu mengikuti jari 1:1 (lebar kartu = setengah putaran),
  // lalu saat dilepas berpegas ke sisi terdekat, atau ke sisi berikutnya bila dikibas.
  double _flipStart = 0;
  double _cardW = 300;

  void _flipDragStart(DragStartDetails _) {
    _flip.stop();
    _flipStart = _flip.value;
    _dragging = true;
  }

  void _flipDragUpdate(DragUpdateDetails d) {
    _flipStart = (_flipStart - (d.primaryDelta ?? 0) / _cardW).clamp(0.0, 1.0);
    _flip.value = _flipStart;
  }

  void _flipDragEnd(DragEndDetails d) {
    _dragging = false;
    final v = -(d.primaryVelocity ?? 0) / _cardW; // putaran per detik
    final target = (v.abs() > 1.2 ? (v > 0 ? 1.0 : 0.0) : (_flip.value > 0.5 ? 1.0 : 0.0));
    if ((target == 1) != _back) tapHaptic();
    _back = target == 1;
    AppSpring.to(_flip, target, velocity: v, spring: AppSpring.heavy, still: reduceMotion(context));
  }

  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    final m = a.member ?? {};
    final calm = reduceMotion(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kartu Anggota')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: _toggle,
                // geser horizontal = balik kartu; geser vertikal = miringkan (dan halaman tetap bisa digulir di luar kartu)
                onHorizontalDragStart: _flipDragStart,
                onHorizontalDragUpdate: _flipDragUpdate,
                onHorizontalDragEnd: _flipDragEnd,
                onVerticalDragStart: (_) => _dragging = true,
                onVerticalDragUpdate: (d) => _tilt.value = Offset(
                  _tilt.value.dx,
                  (_tilt.value.dy + d.delta.dy / 110).clamp(-1.0, 1.0),
                ),
                onVerticalDragEnd: (_) {
                  _dragging = false;
                  _smooth = Offset.zero;
                  _tilt.value = Offset.zero;
                },
                child: LayoutBuilder(builder: (context, box) {
                  _cardW = box.maxWidth <= 0 ? 300 : box.maxWidth;
                  return AspectRatio(
                  aspectRatio: 0.64,
                  child: ValueListenableBuilder<Offset>(
                    valueListenable: _tilt,
                    builder: (context, t0, _) => TweenAnimationBuilder<Offset>(
                      tween: Tween<Offset>(end: calm ? Offset.zero : t0),
                      duration: Duration(milliseconds: _dragging ? 0 : 160),
                      builder: (context, t, __) => AnimatedBuilder(
                        animation: _flip,
                        builder: (context, ___) {
                          final ang = Curves.easeInOutCubic.transform(_flip.value.clamp(0.0, 1.0)) * math.pi;
                          final showBack = ang > math.pi / 2;
                          final mtx = Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..rotateX(-t.dy * 0.32)
                            ..rotateY(ang + t.dx * 0.32);
                          final face = showBack ? _backFace(context, m, t) : _frontFace(context, a, m, t);
                          return Transform(
                            alignment: Alignment.center,
                            transform: mtx,
                            child: showBack ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: face) : face,
                          );
                        },
                      ),
                    ),
                  ),
                );
                }),
              ),
              const SizedBox(height: 18),
              Text(
                kIsWeb ? 'Geser kartu ke samping atau ketuk untuk membalik.' : 'Miringkan HP untuk melihat kilau 3D. Geser ke samping atau ketuk untuk membalik.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kartu ini bukan dokumen resmi pemerintah. Lencana AHU hanya menandai data yang dicocokkan pengelola PERKAPI.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  BoxDecoration _shell(Offset t, {required Gradient gradient}) => BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: gradient,
        boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.38), blurRadius: 30, offset: Offset(-t.dx * 16, 16 - t.dy * 10))],
      );

  Widget _glare(Offset t) => Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment(-1.4 + t.dx * 1.6, -1.4 + t.dy * 1.6),
                end: Alignment(0.6 + t.dx * 1.6, 0.6 + t.dy * 1.6),
                colors: [Colors.transparent, Colors.white.withOpacity(0.05 + 0.2 * t.distance.clamp(0.0, 1.0)), Colors.transparent],
                stops: const [0.25, 0.5, 0.75],
              ),
            ),
          ),
        ),
      );

  Widget _frontFace(BuildContext context, Access a, Map m, Offset t) {
    final ahuNo = '${m['ahu_registration_number'] ?? ''}';
    final verified = m['ahu_verified'] == true;
    return Container(
      decoration: _shell(t, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1A3F), AppColors.navy, Color(0xFF1B3F9A)])),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned(right: -70, bottom: -50, child: Icon(Icons.hexagon_outlined, size: 300, color: Colors.white.withOpacity(0.07))),
          Positioned(left: 0, right: 0, top: 0, child: Container(height: 5, color: AppColors.red)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Column(children: [
              const Row(children: [
                PerkapiLogo(size: 42, onDark: true),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('PERKAPI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                    Text('Kartu Anggota Digital', style: TextStyle(color: Color(0xFFBCC7EA), fontSize: 12)),
                  ]),
                ),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.gold, Color(0xFFB8860B)])),
                child: MemberAvatar(name: a.name, path: a.avatarPath, radius: 54),
              ),
              const SizedBox(height: 16),
              Text(a.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 6),
              Text('No. ${m['member_number'] ?? '-'}', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 15)),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                _chip(a.roleLabel),
                _chip('${m['status'] ?? '-'}'),
              ]),
              const Spacer(),
              if (ahuNo.isNotEmpty)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(verified ? Icons.verified_rounded : Icons.badge_outlined, size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Flexible(child: Text(verified ? 'Terverifikasi AHU' : 'AHU $ahuNo', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13))),
                ]),
              const SizedBox(height: 8),
              Text('Berlaku s/d ${m['valid_until'] ?? '-'}', style: const TextStyle(color: Color(0xFFBCC7EA), fontSize: 12)),
            ]),
          ),
          _glare(t),
        ]),
      ),
    );
  }

  Widget _chip(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
        child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _backFace(BuildContext context, Map m, Offset t) {
    final token = m['qr_token']?.toString();
    final ahuNo = '${m['ahu_registration_number'] ?? ''}';
    return Container(
      decoration: _shell(t, gradient: const LinearGradient(colors: [Colors.white, Color(0xFFEDEFF4)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: 0, child: Container(height: 5, color: AppColors.red)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Pindai untuk verifikasi', style: TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              if (token == null)
                const Text('QR belum tersedia', style: TextStyle(color: AppColors.navy))
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFC9CFDF))),
                  child: QrImageView(data: 'perkapi:member:$token', size: 200),
                ),
              if (ahuNo.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(ahuNo, style: const TextStyle(color: AppColors.navy, fontSize: 12, fontWeight: FontWeight.w600)),
                TextButton.icon(onPressed: () => openAhuOnline(context), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('Buka AHU Online')),
              ],
            ]),
          ),
          _glare(t),
        ]),
      ),
    );
  }
}
