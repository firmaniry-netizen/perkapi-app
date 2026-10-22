import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN aplikasi (6 digit) sebagai kunci lokal di perangkat ini.
/// Disimpan sebagai hash ber-salt di secure storage; PIN asli tidak pernah disimpan.
/// Catatan: PIN 6 digit hanya kunci kenyamanan; keamanan utama tetap login Supabase.
/// Setelah 5 kali salah, pengguna otomatis dikeluarkan (lihat PinPad).
class PinService {
  PinService._();
  static const _s = FlutterSecureStorage();
  static const length = 6;
  static const maxAttempts = 5;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('perkapi:$salt:$pin')).toString();

  static Future<bool> isEnabled() async {
    try {
      return (await _s.read(key: 'pin_hash')) != null;
    } catch (_) {
      return false;
    }
  }

  static bool isWeak(String pin) {
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true; // 000000, 111111
    const seq = '0123456789012345678909876543210';
    return seq.contains(pin);
  }

  static Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await _s.write(key: 'pin_salt', value: salt);
    await _s.write(key: 'pin_hash', value: _hash(pin, salt));
  }

  static Future<bool> verify(String pin) async {
    try {
      final salt = await _s.read(key: 'pin_salt');
      final h = await _s.read(key: 'pin_hash');
      if (salt == null || h == null) return false;
      return _hash(pin, salt) == h;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear() async {
    try {
      await _s.delete(key: 'pin_hash');
      await _s.delete(key: 'pin_salt');
    } catch (_) {}
  }
}
