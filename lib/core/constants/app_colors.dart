import 'package:flutter/material.dart';

/// Palet PERKAPI gaya iOS 27 (Liquid Glass): dongker untuk semua yang bisa ditekan, emas untuk sorotan
/// (status unggulan, angka penting, cahaya latar), merah segel hanya untuk hapus, bahaya dan SOS.
/// Latar netral (abu terang / hitam kebiruan) supaya kaca berwarna lembut di atasnya tetap terbaca.
/// Rasio kontras terukur: putih/dongker 13,8:1 • putih/merah 5,7:1 • dongker/kertas 12,7:1
/// • merah terang/dongker gelap 6,6:1. Merah #C8202F hanya sebagai isi tombol di latar gelap (3,2:1 bila jadi teks).
class AppColors {
  AppColors._();

  // Inti
  static const navy = Color(0xFF0F2B5B); // dongker utama
  static const navyDeep = Color(0xFF08142E); // latar mode gelap
  static const navySurface = Color(0xFF161B26); // sel/kartu mode gelap (abu kebiruan)
  static const navyLine = Color(0xFF2C3342); // garis pemisah mode gelap
  static const navySoft = Color(0xFF98989F); // teks sekunder mode gelap
  static const navyLight = Color(0xFF9DB4E6); // ikon/aksen di latar gelap
  static const navyAction = Color(0xFF2456B8); // tombol umum mode gelap
  static const red = Color(0xFFC8202F); // merah segel
  static const redLight = Color(0xFFFF6B73); // teks/ikon merah di latar gelap
  static const redBright = Color(0xFFE5303E); // ujung terang gradasi merah
  static const navyGlow = Color(0xFF2F6FD6); // ujung terang gradasi dongker
  static const white = Color(0xFFFFFFFF);
  static const paper = Color(0xFFF2F2F7); // latar halaman mode terang (abu iOS)
  static const ink = Color(0xFF000000); // teks utama mode terang
  static const muted = Color(0xFF6C6C70); // teks sekunder mode terang (4,6:1 di latar abu)
  static const line = Color(0xFFC6C6C8); // garis pemisah mode terang

  // Teal, langit dan ungu dilebur ke dongker supaya warna tidak ramai. Emas dipertahankan sebagai warna kedua PERKAPI.
  static const sky = navyAction;
  static const teal = navyAction;
  static const violet = navyAction;
  static const gold = Color(0xFFE8B53A); // emas: teks/ikon di atas dongker atau latar gelap (9,7:1 pada navyDeep)
  static const goldDeep = Color(0xFF9A6B0A); // emas tua: teks/ikon di latar terang (4,7:1 pada putih)
  static const goldHi = Color(0xFFF6CF6F); // ujung terang gradasi emas (foil kartu)

  // Semantik (bukan dekorasi): berhasil & perlu perhatian.
  static const emerald = Color(0xFF1E8A57);
  static const amber = Color(0xFFD98A00);
  static const success = emerald;
  static const warning = amber;

  // Nama lama yang kini dilebur ke emas agar jumlah warna aksen tidak berlebihan (dulu oranye & merah muda).
  static const orange = goldDeep;
  static const rose = goldDeep;

  /// Latar lembut dari warna aksen (ubin ikon, chip). Terang: 12%, gelap: 20%.
  static Color soft(Color c, {required bool dark}) => c.withValues(alpha: dark ? 0.20 : 0.12);

  /// Warna ikon di atas latar lembut: di mode gelap dicerahkan agar kontras.
  static Color onSoft(Color c, {required bool dark}) => dark ? Color.lerp(c, Colors.white, 0.38)! : c;

  /// Gradasi ubin ikon: satu warna, tiga nada (terang kiri atas, dalam kanan bawah).
  static LinearGradient tileGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(c, Colors.white, 0.22)!, c, Color.lerp(c, Colors.black, 0.16)!],
        stops: const [0, 0.55, 1],
      );

  // Warna sistem iOS (mode terang): dipakai untuk ubin ikon berwarna ala aplikasi Pengaturan iPhone.
  static const iosBlue = Color(0xFF007AFF);
  static const iosGreen = Color(0xFF34C759);
  static const iosIndigo = Color(0xFF5856D6);
  static const iosOrange = Color(0xFFFF9500);
  static const iosPink = Color(0xFFFF2D55);
  static const iosPurple = Color(0xFFAF52DE);
  static const iosRed = Color(0xFFFF3B30);
  static const iosTeal = Color(0xFF30B0C7);
  static const iosYellow = Color(0xFFFFB800);
  static const iosMint = Color(0xFF00C7BE);

  /// Warna ubin per modul/rute (cocok untuk id modul maupun path rute), memakai palet sistem iOS:
  /// Kalender merah, Pesan hijau, Catatan kuning, Berita oranye, dan seterusnya, seperti di iPhone.
  static Color forKey(String key) {
    final k = key.toLowerCase();
    bool has(List<String> w) => w.any(k.contains);
    if (has(['complaint', 'pengaduan', 'safety', 'sos', 'alert'])) return iosRed;
    if (has(['case', 'perkara', 'debtor', 'creditor'])) return iosIndigo;
    if (has(['donation', 'donasi'])) return iosPink;
    if (has(['gallery', 'galeri', 'dokumentasi', 'news', 'berita'])) return iosOrange;
    if (has(['document', 'dokumen'])) return iosBlue;
    if (has(['task', 'tugas'])) return iosGreen;
    if (has(['event', 'calendar', 'kalender', 'agenda'])) return iosRed;
    if (has(['forum', 'chat', 'broadcast'])) return iosGreen;
    if (has(['ai'])) return iosPurple;
    if (has(['member', 'anggota', 'branch', 'cabang'])) return iosTeal;
    if (has(['pocket', 'note', 'announcement', 'info'])) return iosYellow;
    if (has(['regulation', 'peraturan', 'profession', 'profesi', 'ahu'])) return iosIndigo;
    if (has(['tracking', 'geofence', 'attendance', 'absensi'])) return iosMint;
    if (has(['setting', 'pengaturan', 'audit', 'report', 'laporan'])) return const Color(0xFF8E8E93);
    return iosBlue;
  }

  // Nama lama (dipertahankan agar layar lain tidak rusak)
  static const lightGray = paper;
  static const darkText = ink;
  static const border = line;
  static const bgDeep = navyDeep;
  static const bgMid = navy;
  static const surfaceDark = navySurface;
  static const blue = navyAction;
  static const blueStrong = navy;
  static const blueLight = navyLight;
  static const textMuted = navySoft;
  static const glassBorder = navyLine;
  static const lightBg = paper;
  static const lightBorder = line;
}
