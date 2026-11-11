import 'package:flutter/material.dart';
import '../../core/constants/phosphor_icons.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.route, {this.perm, this.activeIcon});
  final String label;
  final IconData icon;

  /// Ikon versi terisi untuk keadaan terpilih (navigasi bawah). Null = pakai [icon].
  final IconData? activeIcon;
  final String route;
  final String? perm;
}

/// 4 menu utama + tombol aksi tengah = 5 elemen (batas aman bottom nav). Profil lewat avatar di Beranda.
const bottomItems = [
  NavItem('Beranda', Ph.house, '/dashboard', activeIcon: PhFill.house),
  NavItem('Buku Saku', Ph.bookOpen, '/pocket-book', activeIcon: PhFill.bookOpen),
  NavItem('Profesi', Ph.medal, '/profession', activeIcon: PhFill.medal),
  NavItem('Informasi', Ph.megaphone, '/organization-info', activeIcon: PhFill.megaphone),
];

/// Semua menu (sidebar web / halaman Menu).
const allItems = [
  NavItem('Dashboard', Ph.squaresFour, '/dashboard'),
  NavItem('Anggota', Ph.identificationCard, '/members', perm: 'view_member'),
  // Tidak ada role_permissions bernama approve_registration -> hanya admin utama (SUPER_ADMIN) yang melihat menu ini.
  NavItem('Pendaftaran', Ph.userPlus, '/registrations', perm: 'approve_registration'),
  NavItem('Cabang', Ph.buildings, '/module/branches', perm: 'manage_user'),
  NavItem('Buku Saku', Ph.bookOpen, '/pocket-book'),
  NavItem('Profil Organisasi', Ph.buildings, '/organization-profile'),
  NavItem('Struktur Organisasi', Ph.treeStructure, '/organization-structure'),
  NavItem('Berita & Dokumentasi', Ph.images, '/gallery'),
  NavItem('Informasi', Ph.megaphone, '/organization-info'),
  NavItem('Event', Ph.calendarBlank, '/events'),
  NavItem('Donasi', Ph.handHeart, '/donations'),
  NavItem('Forum', Ph.chatsCircle, '/forum'),
  NavItem('Kalender', Ph.calendarBlank, '/calendar'),
  NavItem('Kotak masuk', Ph.bell, '/inbox'),
  NavItem('AI PERKAPI', Ph.sparkle, '/ai'),
  NavItem('Chat', Ph.chatCircle, '/chat'),
  NavItem('Keamanan & SOS', Ph.shield, '/safety'),
  // Tidak ada role_permissions bernama view_location -> hanya admin utama (SUPER_ADMIN).
  NavItem('Pelacakan GPS', Ph.mapPin, '/tracking', perm: 'view_location'),
  NavItem('Area (Geofence)', Ph.mapPinLine, '/geofences', perm: 'view_location'),
  NavItem('Pengumuman Massal', Ph.megaphone, '/broadcast', perm: 'broadcast'),
  NavItem('Laporan & Ekspor', Ph.chartBar, '/reports', perm: 'view_reports'),
  NavItem('Audit Log', Ph.clock, '/module/audit', perm: 'view_audit_log'),
  NavItem('Kartu Anggota', Ph.qrCode, '/member-card'),
  NavItem('Peraturan & Hukum', Ph.gavel, '/regulations'),
  NavItem('Pendaftaran AHU', Ph.userPlus, '/profession/registration'),
  NavItem('Perpanjangan AHU', Ph.arrowsClockwise, '/profession/renewal'),
  NavItem('Format Laporan AHU', Ph.article, '/profession/reports'),
  NavItem('Data AHU Saya', Ph.sealCheck, '/ahu'),
  NavItem('Verifikasi QR', Ph.shieldCheck, '/verify-member', perm: 'manage_member'),
  NavItem('Pengaturan', Ph.gear, '/settings'),
  NavItem('Profil', Ph.userCircle, '/profile'),
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
