import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Latar bergradasi navy dengan cahaya biru lembut (dipakai di layar utama).
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});
  final Widget child;

  Widget _glow(double size, Color color) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [AppColors.bgMid, AppColors.bgDeep]
                  : const [Color(0xFFE6EEFF), AppColors.lightBg],
            ),
          ),
        ),
      ),
      Positioned(top: -140, left: -90, child: _glow(380, AppColors.blue.withValues(alpha: dark ? 0.32 : 0.14))),
      Positioned(bottom: -160, right: -110, child: _glow(340, AppColors.blueStrong.withValues(alpha: dark ? 0.28 : 0.10))),
      child,
    ]);
  }
}

/// Kartu kaca: isi tembus pandang bergradasi, garis tepi tipis, bayangan lembut.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.blur = false,
    this.gradient,
    this.glow = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Blur latar (lebih berat; pakai hanya untuk elemen besar/jarang).
  final bool blur;

  /// Gradien kustom (mis. kartu utama biru).
  final Gradient? gradient;

  /// Cahaya biru di sekeliling kartu.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final r = BorderRadius.circular(radius);
    final deco = BoxDecoration(
      borderRadius: r,
      gradient: gradient ??
          (dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x26FFFFFF), Color(0x0AFFFFFF)],
                )
              : null),
      color: gradient == null && !dark ? AppColors.white : null,
      border: Border.all(color: dark ? AppColors.glassBorder : AppColors.lightBorder),
      boxShadow: [
        if (glow) BoxShadow(color: AppColors.blue.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 10)),
        BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.05), blurRadius: 20, offset: const Offset(0, 8)),
      ],
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: content),
      );
    }
    Widget box = DecoratedBox(decoration: deco, child: content);
    if (blur) {
      box = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: box),
      );
    }
    return box;
  }
}

/// Tombol utama bergradasi biru dengan cahaya (CTA seperti "Get Started").
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [AppColors.blue, AppColors.blueStrong]),
          boxShadow: [
            BoxShadow(color: AppColors.blue.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(label,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      if (icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(icon, color: Colors.white, size: 20),
                      ],
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon bulat bergaya kaca (menu, notifikasi, filter) dengan lencana opsional.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    Widget i = Icon(icon, size: 22);
    if (badge > 0) {
      i = Badge(label: Text(badge > 99 ? '99+' : '$badge'), backgroundColor: AppColors.blue, child: i);
    }
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: dark ? const Color(0x14FFFFFF) : AppColors.white,
        shape: CircleBorder(side: BorderSide(color: dark ? AppColors.glassBorder : AppColors.lightBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 46, height: 46, child: Center(child: i)),
        ),
      ),
    );
  }
}

/// Judul bagian + tautan "Lihat semua".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!,
                    style: TextStyle(
                        color: _isDark(context) ? AppColors.blueLight : AppColors.blueStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Icon(Icons.chevron_right, size: 18, color: _isDark(context) ? AppColors.blueLight : AppColors.blueStrong),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Ubin aksi cepat (ikon + label) seperti deretan kategori pada desain referensi.
class QuickTile extends StatelessWidget {
  const QuickTile({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    Widget ic = Icon(icon, size: 28, color: dark ? AppColors.blueLight : AppColors.blueStrong);
    if (badge > 0) ic = Badge(label: Text('$badge'), child: ic);
    return SizedBox(
      width: 76,
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ic,
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Wordmark PERKAPI: "PERKA" putih/gelap + "PI" biru.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'PERKA', style: TextStyle(color: onSurface)),
        TextSpan(text: 'PI', style: TextStyle(color: _isDark(context) ? AppColors.blue : AppColors.blueStrong)),
      ]),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 2),
    );
  }
}
