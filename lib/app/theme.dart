import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_tokens.dart';
import '../core/widgets/motion.dart';

/// Tema PERKAPI: dongker (utama), merah segel (aksi), putih (isi).
/// Seluruh teks memakai Plus Jakarta Sans (judul 800 rapat, seperti situs); aksen miring memakai Instrument Serif.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;

    final bg = isDark ? AppColors.navyDeep : AppColors.paper;
    final surface = isDark ? AppColors.navySurface : AppColors.white;
    final line = isDark ? AppColors.navyLine : AppColors.line;
    final onSurface = isDark ? Colors.white : AppColors.ink;
    final muted = isDark ? AppColors.navySoft : AppColors.muted;
    final accent = isDark ? AppColors.navyLight : AppColors.navy; // ikon/teks aksen
    final action = isDark ? AppColors.navyAction : AppColors.navy; // tombol umum

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
    final body = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: onSurface, displayColor: onSurface);
    // Skala tipografi tunggal (lihat AppType). Judul rapat dan tebal, isi lega dan mudah dibaca.
    TextStyle? t(TextStyle? s, double size, FontWeight w, {double ls = 0, double? h}) =>
        GoogleFonts.plusJakartaSans(textStyle: s, fontSize: size, fontWeight: w, letterSpacing: ls, height: h);
    // Judul: Plus Jakarta Sans 800 dengan spasi huruf rapat, sama dengan h1-h3 situs resmi.
    TextStyle? h(TextStyle? s, double size, {double hgt = 1.12}) =>
        t(s, size, FontWeight.w800, ls: -0.025 * size, h: hgt);
    final textTheme = body.copyWith(
      displayLarge: h(body.displayLarge, 36, hgt: 1.08),
      displayMedium: h(body.displayMedium, 32, hgt: 1.08),
      displaySmall: h(body.displaySmall, AppType.display, hgt: 1.12),
      headlineLarge: h(body.headlineLarge, 26),
      headlineMedium: h(body.headlineMedium, 24),
      headlineSmall: h(body.headlineSmall, 22),
      titleLarge: h(body.titleLarge, 20, hgt: 1.2),
      titleMedium: t(body.titleMedium, AppType.title, FontWeight.w800, ls: -0.2, h: 1.3),
      titleSmall: t(body.titleSmall, 15, FontWeight.w700, h: 1.3),
      bodyLarge: t(body.bodyLarge, 16, FontWeight.w500, h: 1.45),
      bodyMedium: t(body.bodyMedium, AppType.body, FontWeight.w500, h: 1.45),
      bodySmall: t(body.bodySmall, AppType.caption, FontWeight.w500, h: 1.4),
      labelLarge: t(body.labelLarge, AppType.body, FontWeight.w700),
      labelMedium: t(body.labelMedium, AppType.caption, FontWeight.w700),
      labelSmall: t(body.labelSmall, AppType.micro, FontWeight.w700, ls: 0.2),
    );

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.control), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeThroughBuilder(),
        TargetPlatform.iOS: FadeThroughBuilder(),
        TargetPlatform.windows: FadeThroughBuilder(),
        TargetPlatform.macOS: FadeThroughBuilder(),
        TargetPlatform.linux: FadeThroughBuilder(),
        TargetPlatform.fuchsia: FadeThroughBuilder(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card), side: BorderSide(color: line.withValues(alpha: isDark ? 1 : 0.7))),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        minVerticalPadding: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: action,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: isDark ? AppColors.navyLine : const Color(0xFFC9D2E6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
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
        fillColor: isDark ? AppColors.navySurface : const Color(0xFFEEF2F9),
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
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
              color: s.contains(WidgetState.selected) ? accent : muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? accent : muted)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: isDark ? AppColors.navyLine : const Color(0xFFC9D2E6),
        dragHandleSize: const Size(44, 5),
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: AppColors.navy.withValues(alpha: 0.35),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface, fontSize: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: line)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF1B2A4A) : AppColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: line),
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: line,
        indicatorColor: AppColors.red,
        labelColor: accent,
        unselectedLabelColor: muted,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: isDark ? AppColors.navyLight : AppColors.navy),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? action : line),
      ),
    );
  }
}
