import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

class NavItem {
  const NavItem(this.label, this.icon, this.route, {this.perm});
  final String label;
  final IconData icon;
  final String route;
  final String? perm;
}

/// 4 menu utama + tombol aksi tengah = 5 elemen (batas aman bottom nav). Profil lewat avatar di Beranda.
const bottomItems = [
  NavItem('Beranda', CupertinoIcons.house, '/dashboard'),
  NavItem('Buku Saku', CupertinoIcons.book, '/pocket-book'),
  NavItem('Profesi', CupertinoIcons.rosette, '/profession'),
  NavItem('Informasi', CupertinoIcons.speaker_2, '/organization-info'),
];

/// Semua menu (sidebar web / halaman Menu).
const allItems = [
  NavItem('Dashboard', CupertinoIcons.square_grid_2x2, '/dashboard'),
  NavItem('Anggota', CupertinoIcons.person_crop_rectangle, '/members', perm: 'view_member'),
  // Tidak ada role_permissions bernama approve_registration -> hanya admin utama (SUPER_ADMIN) yang melihat menu ini.
  NavItem('Pendaftaran', CupertinoIcons.person_badge_plus, '/registrations', perm: 'approve_registration'),
  NavItem('Cabang', CupertinoIcons.building_2_fill, '/module/branches', perm: 'manage_user'),
  NavItem('Buku Saku', CupertinoIcons.book, '/pocket-book'),
  NavItem('Profil Organisasi', CupertinoIcons.building_2_fill, '/organization-profile'),
  NavItem('Struktur Organisasi', CupertinoIcons.list_bullet_indent, '/organization-structure'),
  NavItem('Berita & Dokumentasi', CupertinoIcons.photo_on_rectangle, '/gallery'),
  NavItem('Informasi', CupertinoIcons.speaker_2, '/organization-info'),
  NavItem('Event', CupertinoIcons.calendar, '/events'),
  NavItem('Donasi', CupertinoIcons.heart_circle, '/donations'),
  NavItem('Forum', CupertinoIcons.chat_bubble_2, '/forum'),
  NavItem('Kalender', CupertinoIcons.calendar, '/calendar'),
  NavItem('Kotak masuk', CupertinoIcons.bell, '/inbox'),
  NavItem('AI PERKAPI', CupertinoIcons.sparkles, '/ai'),
  NavItem('Chat', CupertinoIcons.chat_bubble, '/chat'),
  NavItem('Keamanan & SOS', CupertinoIcons.shield, '/safety'),
  // Tidak ada role_permissions bernama view_location -> hanya admin utama (SUPER_ADMIN).
  NavItem('Pelacakan GPS', CupertinoIcons.location, '/tracking', perm: 'view_location'),
  NavItem('Area (Geofence)', CupertinoIcons.placemark, '/geofences', perm: 'view_location'),
  NavItem('Pengumuman Massal', CupertinoIcons.speaker_2, '/broadcast', perm: 'broadcast'),
  NavItem('Laporan & Ekspor', CupertinoIcons.chart_bar, '/reports', perm: 'view_reports'),
  NavItem('Audit Log', CupertinoIcons.clock, '/module/audit', perm: 'view_audit_log'),
  NavItem('Kartu Anggota', CupertinoIcons.qrcode, '/member-card'),
  NavItem('Peraturan & Hukum', CupertinoIcons.hammer, '/regulations'),
  NavItem('Pendaftaran AHU', CupertinoIcons.person_badge_plus, '/profession/registration'),
  NavItem('Perpanjangan AHU', CupertinoIcons.arrow_2_circlepath, '/profession/renewal'),
  NavItem('Format Laporan AHU', CupertinoIcons.doc_plaintext, '/profession/reports'),
  NavItem('Data AHU Saya', CupertinoIcons.checkmark_seal, '/ahu'),
  NavItem('Verifikasi QR', CupertinoIcons.checkmark_shield, '/verify-member', perm: 'manage_member'),
  NavItem('Pengaturan', CupertinoIcons.gear, '/settings'),
  NavItem('Profil', CupertinoIcons.person_crop_circle, '/profile'),
];

int bottomIndexFor(String loc) {
  if (loc.startsWith('/pocket-book') || loc.startsWith('/module/notes')) return 1;
  if (loc.startsWith('/profession') || loc.startsWith('/ahu') || loc.startsWith('/regulations')) return 2;
  if (loc.startsWith('/organization-info') || loc.startsWith('/module/announcements')) return 3;
  if (loc.startsWith('/profile') || loc.startsWith('/settings') || loc.startsWith('/member-card')) return -1;
  return 0;
}

/// Halaman utama yang menampilkan navigasi bawah mengambang (tab + tombol aksi cepat).
/// Halaman lain (dibuka dari menu, punya tombol kembali) menyembunyikannya agar tidak menutupi isi/tombol.
const topLevelRoutes = {'/dashboard', '/pocket-book', '/profession', '/organization-info', '/more'};

bool isTopLevelRoute(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return topLevelRoutes.contains(path.length > 1 && path.endsWith('/') ? path.substring(0, path.length - 1) : path);
}
