import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/perkapi_logo.dart';
import 'auth_repository.dart';

/// Ditampilkan menggantikan seluruh aplikasi bila akun belum disetujui admin utama
/// (mis. sesi lama yang masih tersimpan, atau status diubah saat pengguna sedang login).
///
/// Desain: latar aurora dongker, logo dengan cincin "bernapas" (menandai sedang menunggu),
/// lalu garis waktu 3 langkah agar anggota tahu posisinya: Daftar -> Ditinjau admin -> Aktif.
class PendingApprovalView extends StatefulWidget {
  const PendingApprovalView({super.key});

  @override
  State<PendingApprovalView> createState() => _PendingApprovalViewState();
}

class _PendingApprovalViewState extends State<PendingApprovalView> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await Access.instance.load();
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final a = Access.instance;
    final rejected = a.approvalStatus == 'rejected';
    final reason = (a.member?['rejection_reason'] ?? '').toString();
    final first = a.name.split(' ').first;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Reveal(
                    child: rejected
                        ? const PerkapiLogo(size: 76, onDark: true)
                        : const BreathingRing(child: PerkapiLogo(size: 76, onDark: true, animate: true)),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    index: 1,
                    // Pola judul situs: kata tegas + kata aksen miring emas.
                    child: Text.rich(
                      rejected
                          ? TextSpan(text: 'Pendaftaran ', children: [TextSpan(text: 'tidak disetujui', style: AppType.accent(28, color: AppColors.gold))])
                          : TextSpan(text: 'Halo $first, ', children: [TextSpan(text: 'tinggal selangkah lagi', style: AppType.accent(28, color: AppColors.gold))]),
                      textAlign: TextAlign.center,
                      style: AppType.headline(26, color: Colors.white, height: 1.15),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Reveal(
                    index: 2,
                    child: Text(
                      rejected
                          ? (reason.isEmpty
                              ? 'Admin utama tidak menyetujui pendaftaran Anda. Hubungi sekretariat untuk informasi lebih lanjut.'
                              : 'Alasan: $reason')
                          : 'Akun Anda sudah terdaftar dan sedang ditinjau admin utama. '
                              'Aplikasi terbuka otomatis setelah disetujui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (!rejected)
                    Reveal(
                      index: 3,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: const Column(children: [
                          _Step(title: 'Pendaftaran terkirim', subtitle: 'Data dan dokumen Anda sudah kami terima.', state: _StepState.done),
                          _Step(title: 'Ditinjau admin utama', subtitle: 'Admin utama memeriksa data dan dokumen Anda.', state: _StepState.now),
                          _Step(title: 'Akun aktif', subtitle: 'Kartu anggota digital & semua fitur terbuka.', state: _StepState.next, last: true),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (!rejected)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy),
                      onPressed: _checking ? null : _check,
                      icon: _checking
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_checking ? 'Memeriksa...' : 'Periksa status'),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: 0.85)),
                    onPressed: () => AuthRepository().signOut(),
                    child: const Text('Keluar'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, now, next }

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.subtitle, required this.state, this.last = false});
  final String title, subtitle;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final now = state == _StepState.now;
    final dot = Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.gold : (now ? Colors.white : Colors.transparent),
        border: Border.all(color: done || now ? Colors.transparent : Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 16, color: AppColors.navyDeep)
          : now
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
                )
              : null,
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          dot,
          if (!last)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: done ? AppColors.gold.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.18),
              ),
            ),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: state == _StepState.next ? 0.6 : 1),
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: AppType.caption, height: 1.4)),
            ]),
          ),
        ),
      ]),
    );
  }
}
