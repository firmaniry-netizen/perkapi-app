import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.route, {this.perm});
  final String label;
  final IconData icon;
  final String route;
  final String? perm;
}

/// 4 menu utama + tombol aksi tengah = 5 elemen (batas aman bottom nav). Profil lewat avatar di Beranda.
const bottomItems = [
  NavItem('Beranda', Icons.home_outlined, '/dashboard'),
  NavItem('Buku Saku', Icons.menu_book_outlined, '/pocket-book'),
  NavItem('Profesi', Icons.workspace_premium_outlined, '/profession'),
  NavItem('Informasi', Icons.campaign_outlined, '/organization-info'),
];

/// Semua menu (sidebar web / halaman Menu).
const allItems = [
  NavItem('Dashboard', Icons.dashboard_outlined, '/dashboard'),
  NavItem('Anggota', Icons.badge_outlined, '/members', perm: 'view_member'),
  // Tidak ada role_permissions bernama approve_registration -> hanya admin utama (SUPER_ADMIN) yang melihat menu ini.
  NavItem('Pendaftaran', Icons.how_to_reg_outlined, '/registrations', perm: 'approve_registration'),
  NavItem('Cabang', Icons.location_city_outlined, '/module/branches', perm: 'manage_user'),
  NavItem('Buku Saku', Icons.menu_book_outlined, '/pocket-book'),
  NavItem('Profil Organisasi', Icons.apartment_outlined, '/organization-profile'),
  NavItem('Struktur Organisasi', Icons.account_tree_outlined, '/organization-structure'),
  NavItem('Berita & Dokumentasi', Icons.photo_library_outlined, '/gallery'),
  NavItem('Informasi', Icons.campaign_outlined, '/organization-info'),
  NavItem('Event', Icons.event_outlined, '/events'),
  NavItem('Forum', Icons.forum_outlined, '/forum'),
  NavItem('Kalender', Icons.calendar_month_outlined, '/calendar'),
  NavItem('Kotak masuk', Icons.notifications_none_rounded, '/inbox'),
  NavItem('AI PERKAPI', Icons.auto_awesome_outlined, '/ai'),
  NavItem('Chat', Icons.chat_bubble_outline, '/chat'),
  NavItem('Keamanan & SOS', Icons.shield_outlined, '/safety'),
  // Tidak ada role_permissions bernama view_location -> hanya admin utama (SUPER_ADMIN).
  NavItem('Pelacakan GPS', Icons.my_location_outlined, '/tracking', perm: 'view_location'),
  NavItem('Area (Geofence)', Icons.pin_drop_outlined, '/geofences', perm: 'view_location'),
  NavItem('Pengumuman Massal', Icons.campaign_outlined, '/broadcast', perm: 'broadcast'),
  NavItem('Laporan & Ekspor', Icons.assessment_outlined, '/reports', perm: 'view_reports'),
  NavItem('Audit Log', Icons.history_outlined, '/module/audit', perm: 'view_audit_log'),
  NavItem('Kartu Anggota', Icons.qr_code_2_outlined, '/member-card'),
  NavItem('Peraturan & Hukum', Icons.gavel_outlined, '/regulations'),
  NavItem('Pendaftaran AHU', Icons.how_to_reg_outlined, '/profession/registration'),
  NavItem('Perpanjangan AHU', Icons.autorenew_rounded, '/profession/renewal'),
  NavItem('Format Laporan AHU', Icons.assignment_outlined, '/profession/reports'),
  NavItem('Data AHU Saya', Icons.verified_outlined, '/ahu'),
  NavItem('Verifikasi QR', Icons.verified_user_outlined, '/verify-member', perm: 'manage_member'),
  NavItem('Pengaturan', Icons.settings_outlined, '/settings'),
  NavItem('Profil', Icons.account_circle_outlined, '/profile'),
];

int bottomIndexFor(String loc) {
  if (loc.startsWith('/pocket-book') || loc.startsWith('/module/notes')) return 1;
  if (loc.startsWith('/profession') || loc.startsWith('/ahu') || loc.startsWith('/regulations')) return 2;
  if (loc.startsWith('/organization-info') || loc.startsWith('/module/announcements')) return 3;
  if (loc.startsWith('/profile') || loc.startsWith('/settings') || loc.startsWith('/member-card')) return -1;
  return 0;
}
