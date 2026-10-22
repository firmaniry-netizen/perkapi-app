import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token desain PERKAPI: jarak (kelipatan 4/8), radius, dan skala tipografi.
/// Satu sumber agar semua layar terasa seragam. Jangan pakai angka acak di layar.
class AppSpace {
  AppSpace._();
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double page = 20; // padding horizontal halaman
}

class AppRadius {
  AppRadius._();
  static const double chip = 999;
  static const double control = 14; // tombol kecil, input
  static const double button = 16;
  static const double card = 20;
  static const double hero = 28;
  static const double sheet = 28;
}

/// Skala tipografi: 5 ukuran utama. Dipakai di theme.dart dan widget bersama.
class AppType {
  AppType._();
  static const double display = 28; // angka besar, judul layar utama
  static const double title = 18; // judul bagian/kartu
  static const double body = 14; // isi
  static const double caption = 12; // keterangan, label
  static const double micro = 11; // lencana, label navigasi (ukuran TERKECIL yang boleh dipakai)

  /// Pasangan huruf SITUS RESMI: judul Plus Jakarta Sans 800 rapat, ditambah kata aksen miring emas
  /// berhuruf Instrument Serif (mis. "Berita & *pengumuman*"). Serif dibundel di fonts/.
  static const String accentFamily = 'InstrumentSerif';

  /// Judul tegas (Plus Jakarta Sans 800, spasi huruf rapat seperti h1-h3 situs).
  static TextStyle headline(double size, {Color? color, FontWeight weight = FontWeight.w800, double height = 1.1}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, height: height, letterSpacing: -0.025 * size, color: color);

  /// Kata aksen miring (Instrument Serif italic). Dipakai hemat: sapaan, judul layar sambutan.
  static TextStyle accent(double size, {Color? color, double height = 1.1}) =>
      TextStyle(fontFamily: accentFamily, fontStyle: FontStyle.italic, fontWeight: FontWeight.w400, fontSize: size * 1.08, height: height, color: color);
}

/// Durasi & kurva gerak (satu sumber). Umpan balik cepat, navigasi sedang, dekorasi lambat.
class AppMotion {
  AppMotion._();
  static const quick = Duration(milliseconds: 140); // tekan, toggle
  static const medium = Duration(milliseconds: 320); // kartu, pil navigasi
  static const slow = Duration(milliseconds: 620); // muncul bertahap
  static const emphasized = Cubic(0.16, 1, 0.3, 1); // masuk halus (ease-out kuat)
  static const spring = Curves.easeOutBack; // elemen fisik (tombol, gelembung menu)
}

/// Bayangan dua lapis, bertinta dongker (tidak pernah abu murni).
List<BoxShadow> softShadow({double strength = 1}) => [
      BoxShadow(color: const Color(0xFF0F2B5B).withValues(alpha: 0.06 * strength), blurRadius: 24, offset: const Offset(0, 10)),
      BoxShadow(color: const Color(0xFF0F2B5B).withValues(alpha: 0.04 * strength), blurRadius: 4, offset: const Offset(0, 1)),
    ];
