import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/offline_cache.dart';
import '../../core/services/pin_service.dart';
import '../../core/services/push_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/member_avatar.dart';

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Penanda bahwa form pendaftaran sedang diproses. Selama aktif, router tidak memindahkan
/// pengguna dari /register (signUp bisa membuat sesi sesaat bila konfirmasi email dimatikan).
class RegistrationFlow {
  RegistrationFlow._();
  static bool active = false;
}

class AuthRepository {
  SupabaseClient get _db => SupabaseService.client;

  /// [identifier] dapat berupa email atau nomor anggota.
  /// Nomor anggota diubah menjadi email lewat RPC `resolve_login_email`
  /// (lihat sql/01_resolve_login_email.sql), karena anon tidak boleh
  /// membaca tabel members langsung.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      var email = identifier.trim();
      if (!email.contains('@')) {
        final res = await _db.rpc(
          'resolve_login_email',
          params: {'p_member_number': email},
        );
        if (res is! String || res.isEmpty) {
          throw AuthFailure('Nomor anggota/email atau password salah.');
        }
        email = res;
      }
      await _db.auth.signInWithPassword(email: email, password: password);
      await _assertApproved();
      await _log('login');
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } on PostgrestException {
      throw AuthFailure('Layanan login belum siap. Hubungi admin.');
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
  }

  /// Blokir akun yang belum disetujui admin utama (pending/rejected) dan keluarkan sesinya.
  /// Ini hanya UX; penegak sebenarnya adalah RLS (sql/08_registration_approval.sql).
  /// Jika RPC belum ada (skrip 08 belum dijalankan) perilaku lama dipertahankan.
  Future<void> _assertApproved() async {
    String? status;
    try {
      final res = await _db.rpc('my_approval_status');
      if (res is String) status = res;
    } catch (_) {
      return;
    }
    if (status == null || status == 'approved') return;
    try {
      await _db.auth.signOut();
    } catch (_) {}
    throw AuthFailure(status == 'rejected'
        ? 'Pendaftaran Anda tidak disetujui. Hubungi admin untuk informasi lebih lanjut.'
        : 'Pendaftaran Anda masih menunggu persetujuan admin utama. Anda dapat masuk setelah disetujui.');
  }

  /// Daftar cabang untuk dropdown form register (RPC `public_branches`, boleh dibaca anon).
  Future<List<Map<String, dynamic>>> publicBranches() async {
    try {
      final res = await _db.rpc('public_branches');
      if (res is! List) return [];
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Pendaftaran mandiri. Trigger database membuat baris `members` berstatus `pending`;
  /// akun baru bisa masuk setelah admin utama menyetujui.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? branchId,
  }) async {
    RegistrationFlow.active = true;
    try {
      final res = await _db.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'self_register': true,
          'full_name': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        },
      );
      // Email yang sudah terdaftar (konfirmasi email aktif) dikembalikan tanpa identitas.
      final identities = res.user?.identities;
      if (res.user != null && identities != null && identities.isEmpty) {
        throw AuthFailure('Email ini sudah terdaftar. Silakan masuk atau gunakan "Lupa password".');
      }
      // Konfirmasi email dimatikan -> sesi terbentuk. Akun belum disetujui, jadi keluarkan.
      if (res.session != null) {
        try {
          await _db.auth.signOut();
        } catch (_) {}
      }
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(_friendlyRegister(e));
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    } finally {
      RegistrationFlow.active = false;
    }
  }

  String _friendlyRegister(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Email ini sudah terdaftar. Silakan masuk atau gunakan "Lupa password".';
    }
    if (m.contains('password')) {
      return 'Password terlalu lemah. Gunakan minimal 8 karakter, kombinasi huruf dan angka.';
    }
    if (m.contains('signup') && (m.contains('disabled') || m.contains('not allowed'))) {
      return 'Pendaftaran sedang ditutup. Hubungi admin.';
    }
    if (m.contains('rate') || m.contains('too many') || m.contains('seconds')) {
      return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
    }
    if (m.contains('database error')) {
      return 'Pendaftaran belum dapat diproses. Hubungi admin.';
    }
    if (m.contains('invalid') && m.contains('email')) {
      return 'Format email tidak valid.';
    }
    return 'Pendaftaran gagal. Silakan coba lagi.';
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw AuthFailure(_friendly(e));
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
  }

  /// Hapus data lokal milik pengguna (cache offline & PIN perangkat).
  Future<void> _clearLocal() async {
    AvatarService.clear();
    await OfflineCache.clear();
    await PinService.clear();
  }

  Future<void> _log(String action) async {
    try {
      await _db.rpc('log_event', params: {'p_action': action, 'p_module': 'auth'});
    } catch (_) {}
  }

  Future<void> signOut() async {
    await _log('logout');
    await PushService.instance.unregister();
    await _clearLocal();
    Access.instance.clear();
    await _db.auth.signOut();
  }

  /// Hapus akun sendiri (syarat Google Play). Server menghapus data pribadi, menganonimkan baris anggota
  /// (riwayat perkara/forum tetap utuh), lalu menghapus akun login. Lihat sql/10_delete_account.sql.
  Future<void> deleteAccount() async {
    final path = Access.instance.avatarPath;
    if (path != null) {
      try {
        await _db.storage.from('avatars').remove([path]);
      } catch (_) {} // upaya terbaik; berkas yatim tidak menghalangi penghapusan akun
    }
    try {
      await _db.rpc('delete_my_account');
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message);
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
    await _clearLocal();
    Access.instance.clear();
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  Future<void> signOutAll() async {
    await _log('logout_all');
    await _clearLocal();
    Access.instance.clear();
    await _db.auth.signOut(scope: SignOutScope.global);
  }

  /// Kirim kode OTP ke email (login tanpa password). Hanya untuk akun yang sudah ada.
  /// Pesan sengaja generik agar email terdaftar/tidak terdaftar tidak bisa ditebak.
  Future<void> sendEmailOtp(String email) async {
    try {
      await _db.auth.signInWithOtp(email: email.trim(), shouldCreateUser: false);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('rate') || m.contains('too many') || m.contains('seconds')) {
        throw AuthFailure('Terlalu banyak permintaan. Coba lagi beberapa saat lagi.');
      }
      // lainnya (mis. email tidak terdaftar) diabaikan demi keamanan
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
  }

  Future<void> verifyEmailOtp(String email, String code) async {
    try {
      await _db.auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.email);
      await _assertApproved();
      await _log('login_otp');
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('rate') || m.contains('too many')) {
        throw AuthFailure('Terlalu banyak percobaan. Coba lagi beberapa saat lagi.');
      }
      throw AuthFailure('Kode salah atau sudah kedaluwarsa.');
    } catch (_) {
      throw AuthFailure('Tidak dapat terhubung. Periksa koneksi internet Anda.');
    }
  }

  String _friendly(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Nomor anggota/email atau password salah.';
    }
    if (m.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Periksa kotak masuk Anda.';
    }
    if (m.contains('rate') || m.contains('too many')) {
      return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
    }
    return 'Login gagal. Silakan coba lagi.';
  }
}
