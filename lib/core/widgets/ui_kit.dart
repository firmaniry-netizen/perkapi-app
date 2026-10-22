import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/art_3d.dart';
import '../constants/app_tokens.dart';
import 'illustrations.dart';
import 'motion.dart';

bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Kartu solid: permukaan putih (terang) / dongker (gelap), garis tipis, bayangan lembut.
/// [accentTop] menambah strip merah 3 px di tepi atas (dipakai hanya pada kartu anggota).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.card,
    this.onTap,
    this.color,
    this.accentTop = false,
    this.elevated = true,
    this.wash,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final bool accentTop;
  final bool elevated;

  /// Warna aksen untuk gradasi tipis di latar kartu (kiri atas ke permukaan polos). Opsional.
  final Color? wash;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final r = BorderRadius.circular(radius);
    final bg = color ?? (dark ? AppColors.navySurface : AppColors.white);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: r, onTap: onTap, child: content),
      );
    }
    Widget box = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        gradient: wash == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.alphaBlend(wash!.withValues(alpha: dark ? 0.18 : 0.10), bg), bg],
                stops: const [0, 0.7],
              ),
        borderRadius: r,
        border: Border.all(color: dark ? AppColors.navyLine : AppColors.line.withValues(alpha: 0.7)),
        boxShadow: (elevated && !dark) ? softShadow() : null,
      ),
      child: accentTop
          ? ClipRRect(
              borderRadius: r,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(height: 3, color: AppColors.red),
                content,
              ]),
            )
          : content,
    );
    if (onTap != null) box = Pressable(onTap: onTap, child: box);
    return box;
  }
}

/// Tombol aksi utama: merah segel, teks putih (5,7:1). Memuat -> indikator menggantikan label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final still = reduceMotion(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1,
        child: Pressable(
          onTap: enabled ? () {} : null,
          scale: 0.985,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.redBright, AppColors.red],
              ),
              // Garis putih tipis di tepi atas memberi dimensi tanpa kilap berlebihan.
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.26), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.button),
              onTap: enabled
                  ? () {
                      tapHaptic();
                      onPressed!();
                    }
                  : null,
              child: SizedBox(
                height: 52,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: still ? 0 : 150),
                    child: loading
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(key: const ValueKey('label'), mainAxisSize: MainAxisSize.min, children: [
                            Text(label,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.1)),
                            if (icon != null) ...[
                              const SizedBox(width: 8),
                              Icon(icon, color: Colors.white, size: 20),
                            ],
                          ]),
                  ),
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon kotak membulat (area sentuh 48 px) dengan lencana merah opsional.
class AppIconButton extends StatelessWidget {
  const AppIconButton({super.key, required this.icon, required this.onTap, this.tooltip, this.badge = 0, this.pulse = false});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  /// Berdenyut dua kali saat [badge] naik (hanya untuk lonceng peringatan).
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    Widget i = Icon(icon, size: 22);
    if (badge > 0) {
      i = Badge(
        label: Text(badge > 99 ? '99+' : '$badge'),
        backgroundColor: AppColors.red,
        textColor: Colors.white,
        child: i,
      );
      if (pulse) i = PulseTwice(value: badge, child: i);
    }
    return Tooltip(
      message: tooltip ?? '',
      child: Semantics(
        button: true,
        label: tooltip,
        child: Pressable(
          onTap: onTap,
          child: Material(
            color: dark ? AppColors.navySurface : AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              side: BorderSide(color: dark ? AppColors.navyLine : AppColors.line),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              onTap: () {
                tapHaptic();
                onTap();
              },
              child: SizedBox(width: 48, height: 48, child: Center(child: i)),
            ),
          ),
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
    final link = _dark(context) ? AppColors.navyLight : AppColors.navy;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.redBright, AppColors.red]),
          ),
        ),
        // Judul bagian memakai huruf judul situs (ramping, tegas) agar aplikasi & situs terasa satu merek.
        Expanded(
          child: Text(title, style: AppType.headline(19, color: Theme.of(context).colorScheme.onSurface)),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: link, minimumSize: const Size(48, 48)),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

/// Ubin aksi cepat: ikon dalam lingkaran bertinta + label. Lebar mengikuti sel grid.
class QuickTile extends StatelessWidget {
  const QuickTile({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0, this.color, this.heroTag});
  final Color? color;
  final String? heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final base = color;
    Widget ic = SolidTile(icon: icon, color: base ?? AppColors.navy, size: 52, radius: 18);
    if (heroTag != null) ic = Hero(tag: heroTag!, child: ic);
    if (badge > 0) {
      ic = Badge(label: Text('$badge'), backgroundColor: AppColors.red, textColor: Colors.white, child: ic);
    }
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            tapHaptic();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ic,
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.15)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Grid [QuickTile] dengan tinggi sel TETAP (bukan rasio) yang ikut ukuran font sistem, muat 2 baris label.
/// Rasio (childAspectRatio) membuat sel menyempit di layar kecil dan memicu "BOTTOM OVERFLOWED".
SliverGridDelegate quickTileGrid(BuildContext context, {int columns = 4, double spacing = 4}) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      // padding 12 + ikon 48 + jarak 8 + cadangan 8, ditambah 2 baris teks.
      mainAxisExtent: 76 + MediaQuery.textScalerOf(context).scale(12) * 2.3,
    );

/// Wordmark PERKAPI (Fraunces) dengan titik merah segel.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('PERKAPI',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: c, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 1.2, height: 1)),
      Padding(
        padding: EdgeInsets.only(left: size * 0.12, bottom: size * 0.06),
        child: Container(
          width: size * 0.2,
          height: size * 0.2,
          decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
        ),
      ),
    ]);
  }
}


/// Ubin ikon bergradasi: tiga nada satu warna, kilau lembut di separuh atas, garis kaca tipis,
/// dan bayangan berwarna. Ikon putih dengan bayangan halus agar tetap terbaca di warna terang.
class SolidTile extends StatelessWidget {
  const SolidTile({super.key, required this.icon, required this.color, this.size = 48, this.radius = 16});
  final IconData icon;
  final Color color;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final r = BorderRadius.circular(radius);
    final art = Art3D.forIcon(icon);
    if (art != null) return _art(context, art, dark, r);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: AppColors.tileGradient(color),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: dark ? 0.30 : 0.38), blurRadius: size * 0.38, offset: Offset(0, size * 0.14))],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Colors.white.withValues(alpha: 0.30), Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Icon(icon, size: size * 0.5, color: Colors.white, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 4, offset: const Offset(0, 1))]),
      ]),
    );
  }
  /// Versi bergambar: ubin bernada lembut warna [color] + gambar 3D yang sedikit "keluar" dari ubin.
  Widget _art(BuildContext context, String art, bool dark, BorderRadius r) {
    final bg = dark ? Color.alphaBlend(color.withValues(alpha: 0.24), const Color(0xFF16213F)) : Color.alphaBlend(color.withValues(alpha: 0.10), Colors.white);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).clamp(48, 384).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(bg, Colors.white, dark ? 0.04 : 0.6)!, bg]),
              border: Border.all(color: color.withValues(alpha: dark ? 0.32 : 0.16)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: dark ? 0.18 : 0.14), blurRadius: size * 0.3, offset: Offset(0, size * 0.1))],
            ),
          ),
        ),
        // gambar mengisi ubin & naik 3%: kesan benda 3D "berdiri" di atas ubin
        Transform.translate(
          offset: Offset(0, -size * 0.03),
          child: Image.asset(art, width: size * 0.98, height: size * 0.98, fit: BoxFit.contain, cacheWidth: px, filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Icon(icon, size: size * 0.5, color: color)),
        ),
      ]),
    );
  }
}

/// Kartu statistik: gradasi tipis dari warna aksen, ikon besar samar sebagai tanda air, angka besar (tabular),
/// dan ubin ikon bergradasi. [colors]: warna terakhir dipakai sebagai nada aksen.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.colors});
  final String label;
  final int value;
  final IconData icon;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final scheme = Theme.of(context).colorScheme;
    final tone = colors.last;
    final surface = dark ? AppColors.navySurface : AppColors.white;
    final r = BorderRadius.circular(AppRadius.card);
    return Container(
      decoration: BoxDecoration(borderRadius: r, boxShadow: dark ? null : softShadow(strength: 0.8)),
      child: ClipRRect(
        borderRadius: r,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.alphaBlend(tone.withValues(alpha: dark ? 0.22 : 0.12), surface), surface],
              stops: const [0, 0.85],
            ),
            border: Border.all(color: dark ? AppColors.navyLine : AppColors.line.withValues(alpha: 0.7)),
          ),
          child: Stack(children: [
            Positioned(right: -8, bottom: -14, child: Icon(icon, size: 72, color: tone.withValues(alpha: dark ? 0.10 : 0.07))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppType.caption, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: CountUp(
                        value: value,
                        delay: const Duration(milliseconds: 300),
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: AppType.display,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                SolidTile(icon: icon, color: tone, size: 38, radius: 12),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Kepala layar dongker bergradasi (layar dalam): titik halus, timbangan keadilan, strip merah,
/// judul + subjudul + chip. Teks putih di atas dongker (kontras tinggi).
class ScreenHero extends StatelessWidget {
  const ScreenHero({super.key, required this.title, this.subtitle, this.icon, this.chips = const [], this.accent, this.heroTag});
  final String? heroTag;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<(IconData, String)> chips;
  final Color? accent;

  Widget _heroChip(IconData i) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Icon(i, size: 23, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.sky;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navyDeep, AppColors.navy, Color.lerp(const Color(0xFF1B4A9C), tint, 0.42)!],
          stops: const [0, 0.5, 1],
        ),
        boxShadow: [BoxShadow(color: Color.lerp(AppColors.navy, tint, 0.35)!.withValues(alpha: 0.34), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Stack(children: [
        // Sengaja tanpa foto & pola titik: kepala layar dalam cukup gradasi + satu cahaya warna modul,
        // supaya foto hanya menjadi momen di layar utama (login, kartu anggota) dan tidak terasa diulang-ulang.
        Positioned(
          right: -60,
          top: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [tint.withValues(alpha: 0.50), tint.withValues(alpha: 0)]),
            ),
          ),
        ),
        const Positioned(right: 10, bottom: -8, child: ScalesArt(size: 112, opacity: 0.30)),
        Positioned(
          left: 20,
          bottom: 0,
          child: Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
        ),
        // Garis emas tipis di tepi atas: ciri yang sama dengan kartu anggota & situs resmi.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 1.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0),
                AppColors.gold.withValues(alpha: 0.75),
                AppColors.gold.withValues(alpha: 0),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[
                heroTag == null ? _heroChip(icon!) : Hero(tag: heroTag!, child: _heroChip(icon!)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.headline(22, color: Colors.white)),
                  const SizedBox(height: 2),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 96),
                      child: Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.80), fontSize: 13, height: 1.3)),
                    ),
                ]),
              ),
            ]),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in chips)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.$1, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(c.$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Tombol ikon bergradasi merah segel (area sentuh 48 px) untuk SATU aksi utama di header layar, mis. "Tambah".
class GradientIconButton extends StatelessWidget {
  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.colors = const [AppColors.redBright, AppColors.red],
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            tapHaptic();
            onTap();
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
