import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/widgets/ui_kit.dart';
import 'donation_data.dart';

/// Warna & ikon per kategori kampanye.
(Color, IconData) categoryStyle(String c) => switch (c) {
      'Event' => (AppColors.goldDeep, CupertinoIcons.calendar),
      'Sosial' => (AppColors.teal, CupertinoIcons.person_3),
      'Bencana' => (AppColors.red, CupertinoIcons.drop),
      'Pendidikan' => (AppColors.sky, CupertinoIcons.book_fill),
      'Organisasi' => (AppColors.navyAction, CupertinoIcons.building_2_fill),
      _ => (AppColors.violet, CupertinoIcons.heart_circle),
    };

/// Gambar dari bucket privat lewat URL bertanda tangan; cadangan: gradasi + ikon kategori.
class SignedImage extends StatefulWidget {
  const SignedImage({super.key, required this.bucket, required this.path, required this.fallback, this.fit = BoxFit.cover});
  final String bucket;
  final String? path;
  final Widget fallback;
  final BoxFit fit;
  @override
  State<SignedImage> createState() => _SignedImageState();
}

class _SignedImageState extends State<SignedImage> {
  late Future<String?> _url = DonationRepo.signedUrl(widget.bucket, widget.path);

  @override
  void didUpdateWidget(SignedImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = DonationRepo.signedUrl(widget.bucket, widget.path);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.path == null) return widget.fallback;
    return FutureBuilder<String?>(
      future: _url,
      builder: (_, s) {
        final u = s.data;
        if (u == null) return widget.fallback;
        return Image.network(u, fit: widget.fit, errorBuilder: (_, __, ___) => widget.fallback,
            frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : widget.fallback);
      },
    );
  }
}

/// Latar sampul bawaan saat kampanye belum punya foto.
class CoverFallback extends StatelessWidget {
  const CoverFallback({super.key, required this.category});
  final String category;
  @override
  Widget build(BuildContext context) {
    final (c, ic) = categoryStyle(category);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyDeep, AppColors.navy, Color.lerp(AppColors.navy, c, 0.55)!],
        ),
      ),
      child: Center(child: Icon(ic, size: 44, color: Colors.white.withValues(alpha: 0.55))),
    );
  }
}

/// Bilah kemajuan donasi bergradasi (animasi saat pertama tampil).
class DonationProgress extends StatelessWidget {
  const DonationProgress({super.key, required this.value, this.height = 8});
  final double value;
  final double height;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: dark ? AppColors.navyLine : AppColors.line,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: Duration(milliseconds: MediaQuery.of(context).disableAnimations ? 0 : 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => FractionallySizedBox(
            widthFactor: v.clamp(0.0, 1.0).toDouble(),
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.gold, AppColors.emerald])),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana kecil kategori / status.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon, this.onDark = false});
  final String label;
  final Color color;
  final IconData? icon;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final dark = onDark || Theme.of(context).brightness == Brightness.dark;
    final fg = onDark ? Colors.white : AppColors.onSoft(color, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withValues(alpha: 0.35) : AppColors.soft(color, dark: dark),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}

/// Kartu kampanye di daftar: sampul, kategori, judul, kemajuan, terkumpul & sisa waktu.
class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.c, required this.onTap});
  final Campaign c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final (color, icon) = categoryStyle(c.category);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: Stack(fit: StackFit.expand, children: [
              Hero(
                tag: 'donasi-cover-${c.id}',
                child: SignedImage(bucket: 'donasi-publik', path: c.coverPath, fallback: CoverFallback(category: c.category)),
              ),
              Positioned(left: 12, top: 12, child: Pill(c.category, color: color, icon: icon, onDark: true)),
              if (!c.open)
                Positioned(right: 12, top: 12, child: Pill(c.active ? 'Selesai' : 'Ditutup', color: AppColors.muted, onDark: true)),
              if (c.pending > 0)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Pill('${c.pending} menunggu verifikasi', color: AppColors.amber, icon: CupertinoIcons.hourglass, onDark: true),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppType.lead, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 12),
              if ((c.target ?? 0) > 0) ...[
                DonationProgress(value: c.progress),
                const SizedBox(height: 10),
              ],
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Terkumpul', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(rupiah(c.collected),
                        style: TextStyle(fontSize: AppType.lead, fontWeight: FontWeight.w900, color: AppColors.onSoft(AppColors.emerald, dark: Theme.of(context).brightness == Brightness.dark))),
                    if ((c.target ?? 0) > 0)
                      Text('dari ${rupiah(c.target!)}', style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${c.donors} donatur', style: const TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700)),
                  if (c.timeLeft != null) ...[
                    const SizedBox(height: 2),
                    Text(c.timeLeft!, style: TextStyle(fontSize: AppType.caption, color: sc.onSurfaceVariant)),
                  ],
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Warna & label status donasi.
(Color, String, IconData) donationStatus(String s) => switch (s) {
      'terverifikasi' => (AppColors.emerald, 'Diterima', CupertinoIcons.checkmark_seal_fill),
      'ditolak' => (AppColors.red, 'Ditolak', CupertinoIcons.xmark_circle_fill),
      _ => (AppColors.amber, 'Menunggu verifikasi', CupertinoIcons.hourglass),
    };
