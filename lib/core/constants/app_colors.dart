import 'package:flutter/material.dart';

/// Palet PERKAPI: dongker (utama), merah segel (aksi/peringatan), putih (isi).
/// Rasio kontras terukur: putih/dongker 13,8:1 • putih/merah 5,7:1 • dongker/kertas 12,7:1
/// • merah terang/dongker gelap 6,6:1. Merah #C8202F hanya sebagai isi tombol di latar gelap (3,2:1 bila jadi teks).
class AppColors {
  AppColors._();

  // Inti
  static const navy = Color(0xFF0F2B5B); // dongker utama
  static const navyDeep = Color(0xFF08142E); // latar mode gelap
  static const navySurface = Color(0xFF0F1E3F); // kartu mode gelap
  static const navyLine = Color(0xFF22365F); // garis tipis mode gelap
  static const navySoft = Color(0xFFA9B6D3); // teks redup mode gelap
  static const navyLight = Color(0xFF9DB4E6); // ikon/aksen di latar gelap
  static const navyAction = Color(0xFF2456B8); // tombol umum mode gelap
  static const red = Color(0xFFC8202F); // merah segel
  static const redLight = Color(0xFFFF6B73); // teks/ikon merah di latar gelap
  static const redBright = Color(0xFFE5303E); // ujung terang gradasi merah
  static const navyGlow = Color(0xFF2F6FD6); // ujung terang gradasi dongker
  static const white = Color(0xFFFFFFFF);
  static const paper = Color(0xFFF4F6FB); // latar mode terang
  static const ink = Color(0xFF0B1530); // teks utama mode terang
  static const muted = Color(0xFF5B6785); // teks redup mode terang
  static const line = Color(0xFFE2E7F1); // garis tipis mode terang

  // Aksen tambahan (modern): ikon modul, grafik, dan status. Dongker tetap warna utama,
  // merah tetap untuk aksi utama; warna di bawah hanya pembeda modul agar layar tidak monoton.
  // Palet aksen SELARAS SITUS RESMI (emas, teal, langit, ungu). Emas = warna khas PERKAPI kedua setelah dongker:
  // dipakai untuk berita, agenda, informasi, angka penting, dan lencana terverifikasi.
  static const sky = Color(0xFF2E7BD6);
  static const teal = Color(0xFF0F8F86);
  static const violet = Color(0xFF6D5BD0);
  static const gold = Color(0xFFE8B53A); // emas situs: teks/ikon di atas dongker (9,7:1 pada navyDeep)
  static const goldDeep = Color(0xFF9A6B0A); // emas tua: ubin ikon & teks di latar terang (4,7:1 pada putih)
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

  /// Warna pembeda per modul/rute (cocok untuk id modul maupun path rute).
  static Color forKey(String key) {
    final k = key.toLowerCase();
    bool has(List<String> w) => w.any(k.contains);
    if (has(['case', 'perkara', 'debtor', 'creditor'])) return navyAction;
    if (has(['gallery', 'galeri', 'dokumentasi', 'news', 'berita'])) return goldDeep;
    if (has(['document', 'dokumen'])) return sky;
    if (has(['task', 'tugas'])) return emerald;
    if (has(['complaint', 'pengaduan', 'safety', 'sos', 'alert'])) return red;
    if (has(['event', 'calendar', 'kalender', 'agenda'])) return goldDeep;
    if (has(['forum', 'chat', 'broadcast'])) return violet;
    if (has(['ai'])) return violet;
    if (has(['member', 'anggota', 'branch', 'cabang'])) return teal;
    if (has(['pocket', 'note', 'announcement', 'info'])) return goldDeep;
    if (has(['regulation', 'peraturan', 'profession', 'profesi', 'ahu'])) return navyAction;
    if (has(['tracking', 'geofence', 'attendance', 'absensi'])) return teal;
    return navyAction;
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
