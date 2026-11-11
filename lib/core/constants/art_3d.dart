import 'package:flutter/material.dart';
import 'phosphor_icons.dart';

/// Gambar ikon 3D PERKAPI (images/3d/*.png, 384 px, latar transparan) — dirender khusus dengan warna merek
/// (dongker, emas, merah marun). Dipakai otomatis oleh [SolidTile] / [QuickTile] / [IconBadge] dan ilustrasi
/// keadaan kosong bila ikon yang diminta punya padanan gambar; ikon lain tetap memakai simbol biasa.
/// Sumber model: tools/icon3d/scene.js (three.js). Untuk menambah gambar: render, simpan ke images/3d/, daftarkan di sini.
class Art3D {
  Art3D._();

  static const _dir = 'images/3d/';

  // IconData menimpa ==, jadi tidak bisa dipakai sebagai kunci peta `const`.
  static final Map<IconData, String> _byIcon = {
    for (final i in [Ph.newspaper, Ph.images]) i: 'berita',
    for (final i in [Ph.calendarBlank, Ph.calendarBlank, Ph.calendarBlank, Ph.calendarBlank, Ph.calendarBlank, Ph.calendarPlus]) i: 'kalender',
    for (final i in [Ph.gavel, PhFill.gavel, Ph.gavel]) i: 'hukum',
    for (final i in [Ph.chatsCircle, PhFill.chatsCircle]) i: 'forum',
    for (final i in [Ph.chatCircle, PhFill.chatCircle]) i: 'chat',
    for (final i in [Ph.sparkle, Ph.sparkle, Ph.sparkle]) i: 'ai',
    for (final i in [Ph.squaresFour, Ph.squaresFour, Ph.squaresFour]) i: 'semua',
    for (final i in [Ph.identificationCard, Ph.qrCode]) i: 'kartu',
    Ph.bookOpen: 'saku',
    Ph.medal: 'medali',
    for (final i in [Ph.megaphone, PhFill.megaphone]) i: 'pengumuman',
    for (final i in [Ph.buildings, Ph.buildings, Ph.buildings]) i: 'gedung',
    for (final i in [Ph.treeStructure, Ph.treeStructure]) i: 'struktur',
    Ph.usersThree: 'anggota',
    for (final i in [Ph.shield, Ph.shieldCheck, Ph.hand]) i: 'perisai',
    for (final i in [Ph.mapPin, Ph.mapPinLine, Ph.mapPin, Ph.globe]) i: 'lokasi',
    for (final i in [Ph.chartBar, PhFill.chartBar]) i: 'laporan',
    for (final i in [Ph.article, Ph.fileText, Ph.userPlus, Ph.folder]) i: 'dokumen',
    Ph.sealCheck: 'verifikasi',
    Ph.arrowsClockwise: 'perpanjang',
    for (final i in [
      Ph.bell,
      PhFill.bell,
      Ph.bell,
      Ph.bell,
      PhFill.bell,
      Ph.bell,
    ])
      i: 'lonceng',
    Ph.gear: 'pengaturan',
    for (final i in [Ph.userCircle, Ph.user]) i: 'profil',
    for (final i in [Ph.clock, Ph.clock, Ph.clock]) i: 'riwayat',
    Ph.globe: 'global',
    Ph.house: 'beranda',
  };

  /// Jalur aset gambar 3D untuk [icon], atau null bila tidak ada padanannya.
  static String? forIcon(IconData icon) {
    final n = _byIcon[icon];
    return n == null ? null : '$_dir$n.png';
  }
}
