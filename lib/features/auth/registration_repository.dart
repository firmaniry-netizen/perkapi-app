import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class RegistrationItem {
  RegistrationItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.branchName,
    required this.status,
    this.registeredAt,
    this.rejectionReason,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? branchName;
  final String status;
  final DateTime? registeredAt;
  final String? rejectionReason;

  factory RegistrationItem.fromMap(Map<String, dynamic> m) => RegistrationItem(
        id: m['id'].toString(),
        fullName: (m['full_name'] ?? '').toString(),
        email: (m['email'] ?? '').toString(),
        phone: m['phone'] as String?,
        branchName: m['branch_name'] as String?,
        status: (m['approval_status'] ?? 'pending').toString(),
        registeredAt: m['registered_at'] == null ? null : DateTime.tryParse(m['registered_at'].toString())?.toLocal(),
        rejectionReason: m['rejection_reason'] as String?,
      );
}

class RoleOption {
  const RoleOption(this.code, this.label);
  final String code;
  final String label;
}

/// Akses data persetujuan pendaftaran. Semua RPC memeriksa is_super() di database,
/// jadi pengguna non-admin-utama tidak akan mendapat data walau memanggilnya langsung.
class RegistrationRepository {
  SupabaseClient get _db => SupabaseService.client;

  Future<List<RegistrationItem>> list(String status) async {
    final res = await _db.rpc('list_registrations', params: {'p_status': status});
    if (res is! List) return [];
    return res.map((e) => RegistrationItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> pendingCount() async {
    try {
      final res = await _db.rpc('pending_registration_count');
      return res is int ? res : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Role yang boleh diberikan saat menyetujui (SUPER_ADMIN dikecualikan).
  Future<List<RoleOption>> roles() async {
    const fallback = [
      RoleOption('ANGGOTA', 'ANGGOTA'),
      RoleOption('KURATOR', 'KURATOR'),
      RoleOption('PENGURUS_PKPU', 'PENGURUS PKPU'),
      RoleOption('PENGURUS', 'PENGURUS'),
      RoleOption('STAFF', 'STAFF'),
    ];
    try {
      final res = await _db.from('roles').select('code,name').order('name');
      final out = <RoleOption>[];
      for (final r in res as List) {
        final code = (r['code'] ?? '').toString();
        if (code.isEmpty || code == 'SUPER_ADMIN') continue;
        out.add(RoleOption(code, code.replaceAll('_', ' ')));
      }
      return out.isEmpty ? fallback : out;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> approve({required String memberId, required String roleCode, String? memberNumber}) async {
    await _db.rpc('review_registration', params: {
      'p_member_id': memberId,
      'p_approve': true,
      'p_role_code': roleCode,
      'p_member_number': memberNumber,
    });
  }

  Future<void> reject({required String memberId, String? reason}) async {
    await _db.rpc('review_registration', params: {
      'p_member_id': memberId,
      'p_approve': false,
      'p_reason': reason,
    });
  }
}
