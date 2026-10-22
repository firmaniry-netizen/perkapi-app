import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Profil + role + permission pengguna yang sedang login (dari RPC my_access).
/// Ini hanya untuk UX. Keamanan sebenarnya ditegakkan oleh RLS di database.
class Access extends ChangeNotifier {
  Access._();
  static final Access instance = Access._();

  Map<String, dynamic>? member;
  Set<String> permissions = {};
  List<String> roles = [];
  bool isSuper = false;
  bool loaded = false;
  String? error;

  String? get memberId => member?['id'] as String?;
  String get name => (member?['full_name'] ??
          member?['name'] ??
          SupabaseService.session?.user.email ??
          '')
      .toString();
  /// Status persetujuan pendaftaran: pending | approved | rejected.
  /// Bila kolom belum ada (skrip SQL 08 belum dijalankan) dianggap approved.
  String get approvalStatus => (member?['approval_status'] ?? 'approved').toString();
  bool get isApproved => approvalStatus == 'approved';
  String? get avatarPath {
    final p = member?['avatar_path'];
    return (p is String && p.isNotEmpty) ? p : null;
  }

  /// Menggabungkan kolom anggota yang baru disimpan (mis. data AHU) lalu memberi tahu semua layar.
  void setMemberFields(Map<String, dynamic> fields) {
    member = {...?member, ...fields};
    notifyListeners();
  }

  /// Dipanggil setelah foto profil sendiri berubah agar semua layar ikut diperbarui.
  void setAvatarPath(String? path) {
    member?['avatar_path'] = path;
    notifyListeners();
  }

  /// Admin = SUPER_ADMIN, ADMIN_PUSAT, atau ADMIN_CABANG (sama dengan fungsi is_admin() di sql/21_news_admin.sql).
  /// Hanya untuk menampilkan tombol; penegakan sebenarnya ada di database (RLS).
  bool get isAdmin =>
      isSuper || roles.any((r) => const {'SUPER_ADMIN', 'ADMIN_PUSAT', 'ADMIN_CABANG'}.contains(r.toUpperCase()));

  String get roleLabel => roles.isEmpty ? 'ANGGOTA' : roles.first.replaceAll('_', ' ');

  bool can(String? permission) =>
      permission == null || isSuper || permissions.contains(permission);

  Future<void> load() async {
    loaded = false;
    error = null;
    notifyListeners();
    try {
      final res = await SupabaseService.client.rpc('my_access');
      if (res is Map) {
        member = Map<String, dynamic>.from(res['member'] as Map);
        roles = List<String>.from(res['roles'] as List? ?? []);
        permissions = Set<String>.from(res['permissions'] as List? ?? []);
        isSuper = res['is_super'] == true;
      } else {
        error = 'Akun Anda belum terhubung dengan data anggota. Hubungi admin.';
      }
    } catch (_) {
      error = 'Gagal memuat profil. Pastikan skrip SQL 03 sudah dijalankan.';
    }
    loaded = true;
    notifyListeners();
  }

  void clear() {
    member = null;
    permissions = {};
    roles = [];
    isSuper = false;
    loaded = false;
    error = null;
    notifyListeners();
  }
}
