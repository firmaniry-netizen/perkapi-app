import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';

/// Sisi ANGGOTA. Lokasi hanya dikirim bila database mengizinkan:
/// SOS aktif, atau (anggota sudah menyetujui DAN admin meminta pelacakan). Penegakan ada di `report_location` (SQL 12/14).
/// Setelah aktif, pelacakan berjalan lewat layanan latar (notifikasi tetap "PERKAPI membagikan lokasi")
/// sehingga tetap jalan saat layar mati atau aplikasi di latar. Dimulai saat aplikasi dibuka; bila aplikasi
/// dimatikan paksa, pelacakan berhenti sampai aplikasi dibuka lagi.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  bool consent = false, requested = false, sos = false, sharing = false;
  String? error;
  Timer? _timer;
  StreamSubscription<Position>? _stream;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  void start() {
    if (Access.instance.memberId == null) return;
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => tick());
    tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopStream();
    sharing = false;
  }

  void _stopStream() {
    _stream?.cancel();
    _stream = null;
  }

  Future<void> refreshState() async {
    try {
      final r = await SupabaseService.client.rpc('get_my_location_state');
      if (r is Map) {
        consent = r['consent'] == true;
        requested = r['track_requested'] == true;
        sos = r['sos'] == true;
        error = null;
      }
    } catch (_) {
      error = 'Fitur lokasi belum aktif. Jalankan sql/12_gps_tracking.sql.';
    }
  }

  Future<bool> _permitted(bool interactive) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      error = 'GPS perangkat mati. Aktifkan lokasi.';
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && interactive) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      error = 'Izin lokasi aplikasi belum diberikan.';
      return false;
    }
    return true;
  }

  Future<void> _report(Position p) async {
    _lastSent = DateTime.now();
    try {
      final ok = await SupabaseService.client
          .rpc('report_location', params: {'p_lat': p.latitude, 'p_lng': p.longitude, 'p_acc': p.accuracy});
      sharing = ok == true;
      error = null;
    } catch (_) {
      sharing = false;
      error = 'Gagal mengirim lokasi. Mencoba lagi otomatis.';
    }
    notifyListeners();
  }

  void _startStream() {
    if (_stream != null) return;
    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 20),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'PERKAPI membagikan lokasi',
              notificationText: 'Lokasi Anda sedang dibagikan ke admin. Buka aplikasi untuk menghentikan.',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _stream = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        if (DateTime.now().difference(_lastSent) < const Duration(seconds: 15)) return;
        _report(p);
      },
      onError: (_) {
        _stopStream();
        sharing = false;
        notifyListeners();
      },
    );
  }

  Future<void> tick({bool interactive = false}) async {
    await refreshState();
    if (!(sos || (consent && requested))) {
      _stopStream();
      sharing = false;
      notifyListeners();
      return;
    }
    try {
      if (!await _permitted(interactive)) {
        _stopStream();
        sharing = false;
        notifyListeners();
        return;
      }
      if (_stream == null) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
        );
        await _report(pos);
        _startStream();
      }
    } catch (_) {
      sharing = false;
      error = 'Gagal membaca lokasi. Mencoba lagi otomatis.';
      notifyListeners();
    }
  }

  Future<void> setConsent(bool on) async {
    await SupabaseService.client.rpc('set_location_consent', params: {'p_on': on});
    await tick(interactive: on);
  }

  Future<void> triggerSos(String? note) async {
    await SupabaseService.client.rpc('trigger_sos', params: {'p_note': note});
    await tick(interactive: true);
  }

  Future<void> cancelSos() async {
    await SupabaseService.client.rpc('cancel_sos');
    await tick();
  }

  /// "Saya aman": mencatat check-in; bila SOS aktif, SOS dibatalkan dan admin diberi tahu.
  Future<void> checkIn([String? note]) async {
    await SupabaseService.client.rpc('check_in_safe', params: {'p_note': note});
    await tick();
  }
}
