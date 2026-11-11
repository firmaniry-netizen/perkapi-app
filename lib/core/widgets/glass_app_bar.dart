import 'dart:math' as math;

import '../constants/phosphor_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/nav_items.dart' show isTopLevelRoute;

import '../constants/app_colors.dart';
import 'liquid_glass.dart';

/// Padding daftar untuk halaman dengan `extendBodyBehindAppBar: true`: tambahkan tinggi status bar + bar kaca
/// ke padding atas, supaya isi mulai di bawah bar tetapi tetap bisa digulir lewat DI BELAKANG bar (buram).
EdgeInsets barPad(BuildContext context, EdgeInsets p) {
  // Konteks bisa berada di atas Scaffold (padding = status bar saja) atau di dalam body (padding sudah
  // termasuk tinggi bar). Ambil yang terbesar: status bar asli + tinggi bar, atau padding yang sudah ada.
  final status = MediaQueryData.fromView(View.of(context)).padding.top;
  final top = math.max(MediaQuery.paddingOf(context).top, status + kToolbarHeight);
  return p.copyWith(top: p.top + top);
}

/// App bar ala iOS 26 (Liquid Glass): judul tetap di atas latar halaman, tombol kembali menjadi
/// lingkaran kaca, dan semua aksi di kanan dikumpulkan dalam satu kapsul kaca.
/// Pengganti langsung `AppBar(...)` untuk parameter yang dipakai aplikasi ini.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.titleSpacing,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
  });

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? titleSpacing;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ?? theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    // Latar gelap kustom (mis. penampil foto): kaca bening agar menyatu dengan foto.
    final onDark = backgroundColor != null && backgroundColor!.computeLuminance() < 0.3;
    final route = ModalRoute.of(context);
    final canPop = route?.impliesAppBarDismissal ?? false;
    // Halaman yang dibuka langsung (context.go / notifikasi / tautan) tidak punya riwayat untuk "kembali".
    // Di luar tab utama, tetap tampilkan tombol kembali yang membawa ke Beranda, seperti di iOS.
    var toHome = false;
    if (!canPop && automaticallyImplyLeading && leading == null) {
      try {
        final loc = GoRouterState.of(context).uri.path;
        toHome = loc.isNotEmpty && loc != '/' && !isTopLevelRoute(loc);
      } catch (_) {}
    }

    Widget? lead = leading;
    final glassBack = lead == null && automaticallyImplyLeading && (canPop || toHome);
    if (glassBack) {
      lead = Center(
        child: LiquidGlassButton(
          circle: true,
          size: 40,
          clear: onDark,
          semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
          onTap: () => canPop ? Navigator.maybePop(context) : context.go('/dashboard'),
          child: Icon(Ph.caretLeft, size: 21, color: fg),
        ),
      );
    }

    final acts = actions;
    final List<Widget>? glassActions = (acts == null || acts.isEmpty)
        ? acts
        : [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: LiquidGlass(
                  radius: 24,
                  blur: 14,
                  clear: onDark,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: IconTheme.merge(
                    data: IconThemeData(color: fg),
                    child: SizedBox(height: 46, child: Row(mainAxisSize: MainAxisSize.min, children: acts)),
                  ),
                ),
              ),
            ),
          ];

    // Huruf besar di setelan HP: dibatasi 1,3x agar judul & kapsul kaca tidak terpotong.
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: AppBar(
      title: title,
      leading: lead,
      leadingWidth: glassBack ? 60 : null,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: glassActions,
      bottom: bottom,
      titleSpacing: titleSpacing,
      centerTitle: centerTitle,
      foregroundColor: foregroundColor,
      // Bar kaca: transparan + latar buram. Di halaman yang isinya digulir di belakang bar
      // (extendBodyBehindAppBar), isi tampak samar di balik kaca seperti iOS.
      backgroundColor: backgroundColor ?? Colors.transparent,
      flexibleSpace: backgroundColor == null ? const _GlassBarFill() : null,
    ));
  }
}

/// Latar bar atas berbahan kaca: blur + saturasi, tint warna latar halaman, garis rambut + kaustik di bawah.
class _GlassBarFill extends StatelessWidget {
  const _GlassBarFill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final fill = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: solid ? 1 : 0.72),
        border: Border(bottom: BorderSide(color: (dark ? Colors.white : AppColors.navy).withValues(alpha: dark ? 0.10 : 0.07))),
      ),
      child: const SizedBox.expand(),
    );
    if (solid) return fill;
    return ClipRect(child: BackdropFilter(filter: LiquidGlass.backdrop(22), child: fill));
  }
}
