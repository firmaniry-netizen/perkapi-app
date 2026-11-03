import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

/// Gambar ikon 3D PERKAPI (images/3d/*.png, 384 px, latar transparan) — dirender khusus dengan warna merek
/// (dongker, emas, merah marun). Dipakai otomatis oleh [SolidTile] / [QuickTile] / [IconBadge] dan ilustrasi
/// keadaan kosong bila ikon yang diminta punya padanan gambar; ikon lain tetap memakai simbol biasa.
/// Sumber model: tools/icon3d/scene.js (three.js). Untuk menambah gambar: render, simpan ke images/3d/, daftarkan di sini.
class Art3D {
  Art3D._();

  static const _dir = 'images/3d/';

  // IconData menimpa ==, jadi tidak bisa dipakai sebagai kunci peta `const`.
  static final Map<IconData, String> _byIcon = {
    for (final i in [CupertinoIcons.news, CupertinoIcons.photo_on_rectangle]) i: 'berita',
    for (final i in [CupertinoIcons.calendar, CupertinoIcons.calendar, CupertinoIcons.calendar, CupertinoIcons.calendar, CupertinoIcons.calendar, CupertinoIcons.calendar_badge_plus]) i: 'kalender',
    for (final i in [CupertinoIcons.hammer, CupertinoIcons.hammer_fill, CupertinoIcons.hammer]) i: 'hukum',
    for (final i in [CupertinoIcons.chat_bubble_2, CupertinoIcons.chat_bubble_2_fill]) i: 'forum',
    for (final i in [CupertinoIcons.chat_bubble, CupertinoIcons.chat_bubble_fill]) i: 'chat',
    for (final i in [CupertinoIcons.sparkles, CupertinoIcons.sparkles, CupertinoIcons.sparkles]) i: 'ai',
    for (final i in [CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2]) i: 'semua',
    for (final i in [CupertinoIcons.person_crop_rectangle, CupertinoIcons.qrcode]) i: 'kartu',
    CupertinoIcons.book: 'saku',
    CupertinoIcons.rosette: 'medali',
    for (final i in [CupertinoIcons.speaker_2, CupertinoIcons.speaker_2_fill]) i: 'pengumuman',
    for (final i in [CupertinoIcons.building_2_fill, CupertinoIcons.building_2_fill, CupertinoIcons.building_2_fill]) i: 'gedung',
    for (final i in [CupertinoIcons.list_bullet_indent, CupertinoIcons.list_bullet_indent]) i: 'struktur',
    CupertinoIcons.person_3: 'anggota',
    for (final i in [CupertinoIcons.shield, CupertinoIcons.checkmark_shield, CupertinoIcons.hand_raised]) i: 'perisai',
    for (final i in [CupertinoIcons.location, CupertinoIcons.placemark, CupertinoIcons.location, CupertinoIcons.globe]) i: 'lokasi',
    for (final i in [CupertinoIcons.chart_bar, CupertinoIcons.chart_bar_alt_fill]) i: 'laporan',
    for (final i in [CupertinoIcons.doc_plaintext, CupertinoIcons.doc_text, CupertinoIcons.person_badge_plus, CupertinoIcons.folder]) i: 'dokumen',
    CupertinoIcons.checkmark_seal: 'verifikasi',
    CupertinoIcons.arrow_2_circlepath: 'perpanjang',
    for (final i in [
      CupertinoIcons.bell,
      CupertinoIcons.bell_fill,
      CupertinoIcons.bell,
      CupertinoIcons.bell,
      CupertinoIcons.bell_fill,
      CupertinoIcons.bell,
    ])
      i: 'lonceng',
    CupertinoIcons.gear: 'pengaturan',
    for (final i in [CupertinoIcons.person_crop_circle, CupertinoIcons.person]) i: 'profil',
    for (final i in [CupertinoIcons.clock, CupertinoIcons.clock, CupertinoIcons.clock]) i: 'riwayat',
    CupertinoIcons.globe: 'global',
    CupertinoIcons.house: 'beranda',
  };

  /// Jalur aset gambar 3D untuk [icon], atau null bila tidak ada padanannya.
  static String? forIcon(IconData icon) {
    final n = _byIcon[icon];
    return n == null ? null : '$_dir$n.png';
  }
}
