import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/motion_physics.dart';
import '../../core/services/supabase_service.dart';
import '../ahu/ahu_page.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/constants/app_tokens.dart';

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

  // Penanda tangan di sisi belakang kartu; diperbarui dari tabel struktur organisasi.
  String _ketua = 'Siking Suriyadi, S.H., M.H.';
  String _sekjen = 'Iwan Kurniawan Hamid, S.H.';

  Future<void> _loadSigners() async {
    try {
      final rows = List<Map<String, dynamic>>.from(await SupabaseService.client
          .from('org_structure')
          .select('position, name')
          .inFilter('position', ['Ketua Umum', 'Sekretaris Jenderal']) as List);
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          final n = '${r['name'] ?? ''}'.trim();
          if (n.isEmpty) continue;
          if (r['position'] == 'Ketua Umum') _ketua = n;
          if (r['position'] == 'Sekretaris Jenderal') _sekjen = n;
        }
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadSigners();
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
      appBar: GlassAppBar(title: const Text('Kartu Anggota')),
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
                  aspectRatio: 638 / 1016, // ukuran desain ID card PERKAPI (CR80 tegak)
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
                style: TextStyle(fontSize: AppType.small, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if ('${m['ahu_registration_number'] ?? ''}'.isNotEmpty)
                TextButton.icon(
                  onPressed: () => openAhuOnline(context),
                  icon: const Icon(Ph.arrowSquareOut, size: 16),
                  label: const Text('Buka AHU Online'),
                ),
              const SizedBox(height: 6),
              const Text(
                'Kartu ini bukan dokumen resmi pemerintah. Lencana AHU hanya menandai data yang dicocokkan pengelola PERKAPI.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppType.micro),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static const _ink = Color(0xFF14142B);
  static const _red = Color(0xFFD61F26);
  static const _olive = Color(0xFFA39200);
  static const _bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  String _validUntil(dynamic v) {
    final d = DateTime.tryParse('${v ?? ''}');
    if (d == null) return (v == null || '$v'.isEmpty) ? '-' : '$v';
    return '${_bulan[d.month - 1]} ${d.year}';
  }

  TextStyle _font(double size, {FontWeight w = FontWeight.w600, Color c = _ink, double ls = 0, double h = 1.2}) =>
      GoogleFonts.montserrat(fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h);

  /// Bingkai kartu: latar desain resmi (ornamen + logo), sudut membulat, bayangan ikut kemiringan, kilau.
  Widget _card(Offset t, String bg, Widget Function(double w, double h) content) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final r = BorderRadius.circular(w * 0.05);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.30), blurRadius: 30, offset: Offset(-t.dx * 16, 16 - t.dy * 10))],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(bg, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
            content(w, h),
            _glare(t),
          ]),
        ),
      );
    });
  }

  Widget _glare(Offset t) => Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.4 + t.dx * 1.6, -1.4 + t.dy * 1.6),
                end: Alignment(0.6 + t.dx * 1.6, 0.6 + t.dy * 1.6),
                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.05 + 0.25 * t.distance.clamp(0.0, 1.0)), Colors.transparent],
                stops: const [0.25, 0.5, 0.75],
              ),
            ),
          ),
        ),
      );

  /// Sisi depan: foto anggota dalam cincin merah-zaitun, nama, nomor AHU, masa berlaku.
  Widget _frontFace(BuildContext context, Access a, Map m, Offset t) {
    final ahuNo = '${m['ahu_registration_number'] ?? ''}'.trim();
    final verified = m['ahu_verified'] == true;
    final idLine = ahuNo.isNotEmpty ? ahuNo : 'No. Anggota ${m['member_number'] ?? '-'}';
    return _card(t, 'images/kartu/kartu_depan.jpg', (w, h) {
      final ring = w * 0.43;
      return Stack(children: [
        // foto
        Positioned(
          left: (w - ring) / 2,
          top: h * 0.508 - ring / 2,
          width: ring,
          height: ring,
          child: Container(
            padding: EdgeInsets.all(w * 0.014),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                startAngle: 0,
                endAngle: math.pi * 2,
                colors: [_olive, _olive, _red, _red, _olive],
                stops: [0, 0.32, 0.38, 0.85, 1],
                transform: GradientRotation(-math.pi / 2),
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(w * 0.008),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
              child: ClipOval(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: MemberAvatar(name: a.name, path: a.avatarPath, radius: 120),
                ),
              ),
            ),
          ),
        ),
        // nama + nomor
        Positioned(
          left: w * 0.07,
          right: w * 0.07,
          top: h * 0.685,
          child: Column(children: [
            Text(a.name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _font(w * 0.056, w: FontWeight.w800, h: 1.1)),
            SizedBox(height: h * 0.008),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (verified) ...[
                Icon(PhFill.sealCheck, size: w * 0.042, color: _olive),
                SizedBox(width: w * 0.012),
              ],
              Flexible(child: Text(idLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: _font(w * 0.04, w: FontWeight.w500))),
            ]),
          ]),
        ),
        // masa berlaku
        Positioned(
          left: w * 0.1,
          right: w * 0.1,
          top: h * 0.86,
          child: Text('Berlaku sampai dengan ${_validUntil(m['valid_until'])}',
              textAlign: TextAlign.center, style: _font(w * 0.03, w: FontWeight.w600)),
        ),
      ]);
    });
  }

  /// Sisi belakang: penanda tangan, alamat sekretariat, keterangan, QR verifikasi.
  Widget _backFace(BuildContext context, Map m, Offset t) {
    final token = m['qr_token']?.toString();
    return _card(t, 'images/kartu/kartu_belakang.jpg', (w, h) {
      Widget signer(String name, String title) => Column(children: [
            Text(name, textAlign: TextAlign.center, maxLines: 2, style: _font(w * 0.026, w: FontWeight.w700)),
            SizedBox(height: h * 0.002),
            Text(title, textAlign: TextAlign.center, style: _font(w * 0.024, w: FontWeight.w500)),
          ]);
      final addr = _font(w * 0.031, w: FontWeight.w500, h: 1.35);
      return Stack(children: [
        Positioned(
          left: w * 0.05,
          right: w * 0.05,
          top: h * 0.41,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: signer(_ketua, 'Ketua Umum')),
            SizedBox(width: w * 0.04),
            Expanded(child: signer(_sekjen, 'Sekretaris Jenderal')),
          ]),
        ),
        Positioned(
          left: w * 0.06,
          right: w * 0.06,
          top: h * 0.505,
          child: Column(children: [
            Text('SEKRETARIAT PERKAPI',
                style: _font(w * 0.037, w: FontWeight.w600).copyWith(decoration: TextDecoration.underline, decorationThickness: 1.4)),
            SizedBox(height: h * 0.008),
            Text('SINARMAS LAND PLAZA TOWER III LT. 10\nJalan M.H. Thamrin No.51\nGondangdia Menteng - Jakarta Pusat\nTelepon 021-39711824',
                textAlign: TextAlign.center, style: addr),
          ]),
        ),
        Positioned(
          left: w * 0.065,
          right: w * 0.065,
          top: h * 0.69,
          child: Text(
            'Kartu ini adalah identitas digital resmi anggota Persatuan Kurator dan Pengurus Indonesia. '
            'Pindai kode QR untuk memverifikasi keanggotaan. Bila ditemukan, mohon hubungi Sekretariat PERKAPI.',
            textAlign: TextAlign.justify,
            style: _font(w * 0.027, w: FontWeight.w500, h: 1.35),
          ),
        ),
        Positioned(
          left: w * 0.065,
          top: h * 0.79,
          width: w * 0.21,
          height: w * 0.21,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(w * 0.008),
            child: token == null
                ? Center(child: Text('QR belum tersedia', textAlign: TextAlign.center, style: _font(w * 0.022)))
                : QrImageView(data: 'perkapi:member:$token', padding: EdgeInsets.zero, backgroundColor: Colors.white),
          ),
        ),
        Positioned(
          left: w * 0.3,
          right: w * 0.32,
          top: h * 0.855,
          child: Text('Verifikasi keanggotaan:\nperkapi.or.id', style: _font(w * 0.028, w: FontWeight.w600, h: 1.25)),
        ),
      ]);
    });
  }
}
