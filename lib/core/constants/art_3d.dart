import 'package:flutter/material.dart';

/// Gambar ikon 3D PERKAPI (images/3d/*.png, 384 px, latar transparan) — dirender khusus dengan warna merek
/// (dongker, emas, merah marun). Dipakai otomatis oleh [SolidTile] / [QuickTile] / [IconBadge] dan ilustrasi
/// keadaan kosong bila ikon yang diminta punya padanan gambar; ikon lain tetap memakai simbol biasa.
/// Sumber model: tools/icon3d/scene.js (three.js). Untuk menambah gambar: render, simpan ke images/3d/, daftarkan di sini.
class Art3D {
  Art3D._();

  static const _dir = 'images/3d/';

  // IconData menimpa ==, jadi tidak bisa dipakai sebagai kunci peta `const`.
  static final Map<IconData, String> _byIcon = {
    for (final i in [Icons.newspaper_rounded, Icons.photo_library_outlined]) i: 'berita',
    for (final i in [Icons.event_outlined, Icons.event_rounded, Icons.event, Icons.calendar_month_outlined, Icons.calendar_month_rounded, Icons.event_available_rounded]) i: 'kalender',
    for (final i in [Icons.gavel_outlined, Icons.gavel_rounded, Icons.balance_rounded]) i: 'hukum',
    for (final i in [Icons.forum_outlined, Icons.forum_rounded]) i: 'forum',
    for (final i in [Icons.chat_bubble_outline, Icons.chat_bubble_rounded]) i: 'chat',
    for (final i in [Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, Icons.auto_awesome]) i: 'ai',
    for (final i in [Icons.grid_view_rounded, Icons.apps_rounded, Icons.dashboard_outlined]) i: 'semua',
    for (final i in [Icons.badge_outlined, Icons.qr_code_2_outlined]) i: 'kartu',
    Icons.menu_book_outlined: 'saku',
    Icons.workspace_premium_outlined: 'medali',
    for (final i in [Icons.campaign_outlined, Icons.campaign_rounded]) i: 'pengumuman',
    for (final i in [Icons.apartment_outlined, Icons.location_city_outlined, Icons.account_balance_outlined]) i: 'gedung',
    for (final i in [Icons.account_tree_outlined, Icons.account_tree_rounded]) i: 'struktur',
    Icons.groups_outlined: 'anggota',
    for (final i in [Icons.shield_outlined, Icons.verified_user_outlined, Icons.privacy_tip_outlined]) i: 'perisai',
    for (final i in [Icons.my_location_outlined, Icons.pin_drop_outlined, Icons.location_on_outlined, Icons.travel_explore_rounded]) i: 'lokasi',
    for (final i in [Icons.assessment_outlined, Icons.insights_rounded]) i: 'laporan',
    for (final i in [Icons.assignment_outlined, Icons.description_outlined, Icons.how_to_reg_outlined, Icons.folder_outlined]) i: 'dokumen',
    Icons.verified_outlined: 'verifikasi',
    Icons.autorenew_rounded: 'perpanjang',
    for (final i in [
      Icons.notifications_none_rounded,
      Icons.notifications_rounded,
      Icons.notifications_outlined,
      Icons.notifications_active_outlined,
      Icons.notifications_active_rounded,
      Icons.notification_important_outlined,
    ])
      i: 'lonceng',
    Icons.settings_outlined: 'pengaturan',
    for (final i in [Icons.account_circle_outlined, Icons.person_outline]) i: 'profil',
    for (final i in [Icons.history_outlined, Icons.history, Icons.schedule_rounded]) i: 'riwayat',
    Icons.public_rounded: 'global',
    Icons.home_outlined: 'beranda',
  };

  /// Jalur aset gambar 3D untuk [icon], atau null bila tidak ada padanannya.
  static String? forIcon(IconData icon) {
    final n = _byIcon[icon];
    return n == null ? null : '$_dir$n.png';
  }
}
