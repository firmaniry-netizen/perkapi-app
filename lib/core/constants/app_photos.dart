import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// Foto latar aplikasi (images/foto/, maks. 1280 px, JPEG ~45-160 KB):
/// - foto asli kegiatan PERKAPI: pengukuhan & rapat kerja pengurus 2026, plakat, sumpah pengurus;
/// - foto bebas pakai dari Unsplash (lisensi Unsplash): gedung pengadilan, buku hukum, kota Jakarta,
///   rapat, konferensi, kalender, jabat tangan, koran, tanda tangan, kantor, gradasi ala wallpaper iOS.
/// Dipakai sebagai latar kepala layar ([ScreenHero]) dan kartu foto di beranda, menggantikan ikon 3D.
class AppPhotos {
  AppPhotos._();

  static const _d = 'images/foto/';
  // Kegiatan PERKAPI
  static const panggung = '${_d}panggung.jpg';
  static const ruangAcara = '${_d}ruang_acara.jpg';
  static const plakat = '${_d}plakat.jpg';
  static const mejaAcara = '${_d}meja_acara.jpg';
  static const rapat = '${_d}rapat.jpg';
  static const pembicara = '${_d}pembicara.jpg';
  static const pelantikan = '${_d}pelantikan.jpg';
  static const palu = '${_d}palu.jpg';
  static const mejaKerja = '${_d}meja_kerja.jpg';
  static const timbangan = '${_d}timbangan.jpg';
  // Unsplash
  static const kota = '${_d}kota.jpg';
  static const pengadilan = '${_d}pengadilan.jpg';
  static const bukuHukum = '${_d}buku_hukum.jpg';
  static const kantor = '${_d}kantor.jpg';
  static const koran = '${_d}koran.jpg';
  static const rapatBisnis = '${_d}rapat_bisnis.jpg';
  static const gradasi = '${_d}gradasi_ungu.jpg';
  static const diskusi = '${_d}diskusi.jpg';
  static const jabatTangan = '${_d}jabat_tangan.jpg';
  static const konferensi = '${_d}konferensi.jpg';
  static const kalender = '${_d}kalender.jpg';
  static const tandaTangan = '${_d}tanda_tangan.jpg';

  static final Map<IconData, String> _byIcon = {
    CupertinoIcons.hammer_fill: pengadilan,
    CupertinoIcons.hammer: pengadilan,
    for (final i in [CupertinoIcons.folder, CupertinoIcons.doc_text, CupertinoIcons.doc_plaintext, CupertinoIcons.person_badge_plus]) i: tandaTangan,
    CupertinoIcons.news: koran,
    CupertinoIcons.photo_on_rectangle: panggung,
    CupertinoIcons.calendar: kalender,
    CupertinoIcons.speaker_2: konferensi,
    CupertinoIcons.speaker_2_fill: konferensi,
    for (final i in [CupertinoIcons.rosette, CupertinoIcons.arrow_2_circlepath, CupertinoIcons.checkmark_shield_fill, CupertinoIcons.checkmark_seal]) i: plakat,
    for (final i in [CupertinoIcons.chat_bubble_2, CupertinoIcons.chat_bubble_2_fill, CupertinoIcons.chat_bubble_fill]) i: diskusi,
    CupertinoIcons.heart_circle: jabatTangan,
    CupertinoIcons.person_crop_rectangle: pelantikan,
    CupertinoIcons.person_3: rapatBisnis,
    CupertinoIcons.list_bullet_indent: pelantikan,
    CupertinoIcons.book: bukuHukum,
    CupertinoIcons.chart_bar_alt_fill: kantor,
    CupertinoIcons.clock: kantor,
    CupertinoIcons.building_2_fill: kota,
    CupertinoIcons.sparkles: gradasi,
    for (final i in [CupertinoIcons.shield_fill, CupertinoIcons.location_solid, CupertinoIcons.bell_fill, CupertinoIcons.bell]) i: kota,
  };

  /// Foto untuk ikon modul; tanpa padanan memakai foto panggung pengukuhan PERKAPI.
  static String forIcon(IconData? icon) => (icon == null ? null : _byIcon[icon]) ?? panggung;
}
