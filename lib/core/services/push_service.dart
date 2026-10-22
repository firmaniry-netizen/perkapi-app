import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import 'supabase_service.dart';

/// Push saat aplikasi TERTUTUP/di latar (FCM). Saat aplikasi terbuka, banner realtime (LiveNotifier) yang dipakai.
/// Aman bila Firebase belum dikonfigurasi: semua fungsi diam-diam tidak melakukan apa-apa.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool available = false;
  bool registered = false; // token HP ini sudah tersimpan di server
  String? lastError;
  GoRouter? _router;
  String? _token;
  StreamSubscription<String>? _refreshSub;
  bool _wired = false;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Panggil sekali di main() sebelum runApp.
  static Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      instance.available = true;
    } catch (_) {
      instance.available = false;
    }
  }

  void attachRouter(GoRouter router) {
    _router = router;
    if (!available || _wired) return;
    _wired = true;
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) _open(m);
    });
  }

  void _open(RemoteMessage m) {
    final link = m.data['link'];
    if (link is String && link.startsWith('/')) _router?.go(link);
  }

  /// Dipanggil setelah login dan profil termuat: minta izin, ambil token, simpan ke server.
  Future<void> register() async {
    if (!available) return;
    try {
      final fm = FirebaseMessaging.instance;
      final perm = await fm.requestPermission();
      if (perm.authorizationStatus == AuthorizationStatus.denied) return;
      // Di iPhone, token APNs bisa belum siap saat aplikasi baru dibuka: tunggu sebentar.
      if (_isIos) {
        String? apns;
        for (var i = 0; i < 10 && apns == null; i++) {
          apns = await fm.getAPNSToken();
          if (apns == null) await Future.delayed(const Duration(seconds: 1));
        }
      }
      _token = await fm.getToken();
      registered = await _send(_token);
      _refreshSub ??= fm.onTokenRefresh.listen((t) async {
        _token = t;
        registered = await _send(t);
      });
    } catch (e) {
      lastError = '$e';
      if (kDebugMode) debugPrint('push register: $e');
    }
  }

  Future<bool> _send(String? t) async {
    if (t == null) return false;
    try {
      final platform = _isIos ? 'ios' : 'android';
      await SupabaseService.client.rpc('register_device_token',
          params: {'p_token': t, 'p_platform': platform});
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  /// Ringkasan untuk halaman "Notifikasi & Pengingat". Tidak pernah melempar galat.
  Future<PushStatus> status() async {
    if (!available) {
      return PushStatus(
          configured: false,
          permission: 'n/a',
          hasToken: false,
          registered: false,
          error: lastError);
    }
    var perm = 'notDetermined';
    try {
      final st = await FirebaseMessaging.instance.getNotificationSettings();
      perm = switch (st.authorizationStatus) {
        AuthorizationStatus.authorized => 'granted',
        AuthorizationStatus.provisional => 'granted',
        AuthorizationStatus.denied => 'denied',
        AuthorizationStatus.notDetermined => 'notDetermined',
        // Versi baru firebase_messaging menambah 'deniedPermanently'; wildcard ini menutupnya.
        _ => 'denied',
      };
    } catch (e) {
      lastError = '$e';
    }
    return PushStatus(
        configured: true,
        permission: perm,
        hasToken: _token != null,
        registered: registered,
        error: lastError);
  }

  /// Panggil SEBELUM signOut agar HP ini berhenti menerima notifikasi akun tersebut.
  Future<void> unregister() async {
    final t = _token;
    if (!available || t == null) return;
    try {
      await SupabaseService.client
          .rpc('unregister_device_token', params: {'p_token': t});
    } catch (_) {}
  }
}

/// Status push pada perangkat ini. [permission]: granted | denied | notDetermined | n/a.
class PushStatus {
  const PushStatus({
    required this.configured,
    required this.permission,
    required this.hasToken,
    required this.registered,
    this.error,
  });
  final bool configured;
  final String permission;
  final bool hasToken;
  final bool registered;
  final String? error;
}