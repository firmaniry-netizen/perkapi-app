import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/liquid_glass.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/perkapi_logo.dart';
import '../../core/constants/app_tokens.dart';

const _welcomeKey = 'welcome_done';

/// Apakah sambutan sudah pernah dilihat di perangkat ini.
Future<bool> welcomeSeen() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_welcomeKey) ?? false;
  } catch (_) {
    return true; // jika penyimpanan gagal, jangan menahan pengguna
  }
}

/// Sambutan 3 layar untuk pengguna baru (hanya sekali per perangkat).
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _pc = PageController();
  int _i = 0;

  static const _slides = <(IconData, String, String)>[
    (Ph.gavel, 'Wadah profesi\nkurator dan pengurus', 'PERKAPI mempertemukan anggota, informasi, dan rujukan hukum dalam satu tempat.'),
    (Ph.squaresFour, 'Semua kebutuhan\ndalam satu aplikasi', 'Agenda, berita, buku saku, forum, dan notifikasi organisasi ada di genggaman Anda.'),
    (PhFill.identificationCard, 'Kartu anggota\ndigital', 'Tunjukkan kartu berQR dan verifikasi anggota dengan cepat, kapan saja.'),
  ];

  Future<void> _finish() async {
    tapHaptic();
    try {
      (await SharedPreferences.getInstance()).setBool(_welcomeKey, true);
    } catch (_) {}
    if (!mounted) return;
    context.go(SupabaseService.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login);
  }

  void _next() {
    tapHaptic();
    if (_i >= _slides.length - 1) {
      _finish();
    } else {
      _pc.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0.5, -0.4), radius: 1.2, colors: [Color(0xFF1B3F9A), AppColors.navy, Color(0xFF091434)]),
        ),
        // Cahaya aurora bergerak pelan di belakang: memberi kaca sesuatu untuk dibiaskan.
        child: AuroraBackground(child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                const PerkapiLogo(size: 36, onDark: true),
                const SizedBox(width: 10),
                const Text('PERKAPI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 2)),
                const Spacer(),
                if (!last) TextButton(onPressed: _finish, child: const Text('Lewati', style: TextStyle(color: Color(0xFFBCC7EA)))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, k) {
                  final s = _slides[k];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Bola kaca emas: tint emas tembus pandang + pendar, ikon putih.
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: LiquidGlass(
                          shape: BoxShape.circle,
                          blur: 16,
                          tint: AppColors.gold.withValues(alpha: 0.55),
                          glow: AppColors.gold,
                          child: Center(child: Icon(s.$1, size: 56, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(s.$2, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700, height: 1.1)),
                      const SizedBox(height: 14),
                      Text(s.$3, style: const TextStyle(color: Color(0xFFCBD5F4), fontSize: AppType.lead, height: 1.5)),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Row(children: [
                for (var k = 0; k < _slides.length; k++)
                  AnimatedContainer(
                    duration: Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 250),
                    curve: const Cubic(0.23, 1, 0.32, 1),
                    margin: const EdgeInsets.only(right: 8),
                    height: 6,
                    width: k == _i ? 28 : 8,
                    decoration: BoxDecoration(color: k == _i ? AppColors.gold : Colors.white30, borderRadius: BorderRadius.circular(6)),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red.withValues(alpha: 0.88),
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.45))),
                  ),
                  onPressed: _next,
                  child: Text(last ? 'Mulai' : 'Lanjut', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        )),
      ),
    );
  }
}