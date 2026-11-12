import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';

/// Tema PERKAPI: dongker (utama), merah segel (aksi), putih (isi).
/// Seluruh teks memakai huruf sistem (SF Pro di iPhone, Roboto di Android) dengan bobot dan spasi huruf gaya iOS.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;

    // Gelap: hitam kebiruan, senada dongker. Terang: abu iOS.
    final bg = isDark ? const Color(0xFF070B14) : AppColors.paper;
    final surface = isDark ? AppColors.navySurface : AppColors.white;
    final line = isDark ? AppColors.navyLine : AppColors.line;
    final onSurface = isDark ? Colors.white : AppColors.ink;
    final muted = isDark ? AppColors.navySoft : AppColors.muted;
    final accent = isDark ? AppColors.navyLight : AppColors.navy; // ikon/teks aksen
    final action = isDark ? AppColors.navyAction : AppColors.navy; // tombol umum
    // Liquid Glass (iOS 26): permukaan mengambang tembus pandang + kilau tepi putih tipis.
    final glassFill = surface.withValues(alpha: isDark ? 0.74 : 0.80);
    final glassRim = BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.75));

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.navy, brightness: b).copyWith(
      primary: isDark ? AppColors.navyLight : AppColors.navy,
      onPrimary: isDark ? AppColors.navyDeep : Colors.white,
      primaryContainer: isDark ? const Color(0xFF16336E) : const Color(0xFFE3EAF8),
      onPrimaryContainer: isDark ? Colors.white : AppColors.navy,
      secondary: AppColors.red,
      onSecondary: Colors.white,
      error: isDark ? AppColors.redLight : const Color(0xFFB3261E),
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final body = base.textTheme.apply(bodyColor: onSurface, displayColor: onSurface);
    // Skala tipografi tunggal (lihat AppType). Judul rapat dan tebal, isi lega dan mudah dibaca.
    TextStyle? t(TextStyle? s, double size, FontWeight w, {double ls = 0, double? h}) =>
        s?.copyWith(fontSize: size, fontWeight: w, letterSpacing: ls, height: h);
    // Judul: tebal 700 dengan spasi huruf sedikit renggang, seperti judul besar iOS (SF Pro Display).
    TextStyle? h(TextStyle? s, double size, {double hgt = 1.12}) =>
        t(s, size, FontWeight.w700, ls: 0.35, h: hgt);
    final textTheme = body.copyWith(
      displayLarge: h(body.displayLarge, 36, hgt: 1.08),
      displayMedium: h(body.displayMedium, 32, hgt: 1.08),
      displaySmall: h(body.displaySmall, AppType.display, hgt: 1.12),
      headlineLarge: h(body.headlineLarge, 26),
      headlineMedium: h(body.headlineMedium, 24),
      headlineSmall: h(body.headlineSmall, 22),
      titleLarge: h(body.titleLarge, 20, hgt: 1.2),
      titleMedium: t(body.titleMedium, AppType.title, FontWeight.w600, ls: -0.4, h: 1.3),
      titleSmall: t(body.titleSmall, 15, FontWeight.w600, ls: -0.2, h: 1.3),
      bodyLarge: t(body.bodyLarge, 16, FontWeight.w400, ls: -0.3, h: 1.45),
      bodyMedium: t(body.bodyMedium, AppType.body, FontWeight.w400, ls: -0.2, h: 1.45),
      bodySmall: t(body.bodySmall, AppType.caption, FontWeight.w400, h: 1.4),
      labelLarge: t(body.labelLarge, AppType.body, FontWeight.w600, ls: -0.2),
      labelMedium: t(body.labelMedium, AppType.caption, FontWeight.w600),
      labelSmall: t(body.labelSmall, AppType.micro, FontWeight.w600, ls: 0.1),
    );

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      // Perilaku iOS di semua HP: transisi geser + usap dari tepi kiri untuk kembali, sakelar & seleksi teks gaya iOS.
      platform: TargetPlatform.iOS,
      // Tanpa riak Material: saat ditekan permukaan hanya meredup sesaat, seperti di iOS.
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      }),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface, fontSize: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      // Baris daftar ala iOS: judul tebal, subjudul redup, jarak ikon-teks lega.
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        minVerticalPadding: 10,
        horizontalTitleGap: 14,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: textTheme.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w700),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: muted, height: 1.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          // Tombol kapsul seperti iOS 26/27.
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: isDark ? AppColors.navyLine : const Color(0xFFC9D2E6)),
          shape: const StadiumBorder(),
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent, minimumSize: const Size(48, 44)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.navySurface : const Color(0x1F767680),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(accent, 1.6),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.navy.withValues(alpha: 0.10),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: AppType.micro,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? accent : muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? accent : muted)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // tombol kaca merah: tint tembus pandang + kilau tepi putih
        backgroundColor: AppColors.red.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        elevation: 6,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999), side: BorderSide(color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.55))),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: glassFill,
        modalBackgroundColor: glassFill,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.navyLine : const Color(0xFFC9D2E6),
        dragHandleSize: const Size(44, 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), side: glassRim),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: glassFill,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: AppColors.navy.withValues(alpha: 0.35),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface, fontSize: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: glassRim),
      ),
      // Pesan singkat gaya iOS: kapsul abu gelap tanpa garis tepi.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xF22C2C2E),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      // Chip gaya iOS: isi abu tipis tanpa garis tepi; yang terpilih berlatar warna aksen tipis, tanpa centang.
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0x3D767680) : const Color(0x1F767680),
        selectedColor: accent.withValues(alpha: 0.18),
        showCheckmark: false,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      // Tab = kontrol segmen kaca: pil kaca terang menandai tab aktif (tanpa garis bawah).
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.22 : 1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        labelColor: accent,
        unselectedLabelColor: muted,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: isDark ? AppColors.navyLight : AppColors.navy),
      // Sakelar gaya iOS: jalur hijau sistem saat aktif, abu tembus saat mati, kenop putih, tanpa garis tepi.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
            ? (isDark ? const Color(0xFF30D158) : const Color(0xFF34C759))
            : (isDark ? const Color(0x52787880) : const Color(0x29787880))),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
