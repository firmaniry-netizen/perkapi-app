import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart' as ck;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Layar "panggilan masuk" bawaan sistem untuk saat aplikasi TERTUTUP / di latar (Android).
///
/// Alurnya: penelepon mengirim offer → trigger database membuat notifikasi bertipe `call` →
/// fungsi `send-push` mengirim pesan data FCM berprioritas tinggi → [handlePush] (dijalankan di
/// latar oleh FCM, lihat main.dart) menampilkan layar dering penuh dengan tombol Jawab/Tolak dan
/// nada dering HP. Saat Jawab ditekan, aplikasi terbuka dan CallService langsung menyambungkan.
///
/// iPhone: Apple hanya mengizinkan layar panggilan seperti ini lewat VoIP push (PushKit), jadi di
/// iPhone panggilan masuk tampil sebagai notifikasi berbunyi; mengetuknya membuka layar panggilan.
class IncomingCallUi {
  IncomingCallUi._();

  static bool get supported => !kIsWeb && Platform.isAndroid;
  static StreamSubscription<dynamic>? _sub;

  /// Dipanggil dari penangan pesan FCM latar (isolate terpisah) maupun saat aplikasi terbuka.
  static Future<void> handlePush(Map<String, dynamic> data) async {
    if (!supported) return;
    final type = '${data['type'] ?? ''}';
    final id = '${data['call_id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      if (type == 'call') {
        final video = '${data['video']}' == '1';
        await FlutterCallkitIncoming.showCallkitIncoming(ck.CallKitParams(
          id: id,
          nameCaller: '${data['caller'] ?? 'Anggota PERKAPI'}',
          appName: 'PERKAPI',
          handle: video ? 'Panggilan video PERKAPI' : 'Panggilan suara PERKAPI',
          type: video ? 1 : 0,
          duration: 45000,
          // notifikasi "tak terjawab" dikirim server (tipe call_missed), jangan dobel
          missedCallNotification: ck.NotificationParams(showNotification: false, isShowCallback: false),
          extra: <String, dynamic>{'call_id': id, 'thread_id': '${data['thread_id'] ?? ''}', 'video': video ? '1' : '0'},
          android: ck.AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'system_ringtone_default',
            backgroundColor: '#0E1F4D',
            actionColor: '#16A34A',
            incomingCallNotificationChannelName: 'Panggilan masuk',
            missedCallNotificationChannelName: 'Panggilan tak terjawab',
            textAccept: 'Jawab',
            textDecline: 'Tolak',
          ),
        ));
      } else if (type == 'call_missed') {
        await FlutterCallkitIncoming.endCall(id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('callkit: $e');
    }
  }

  /// Tutup layar dering bawaan (dipanggil saat panggilan dijawab/diakhiri di dalam aplikasi).
  static Future<void> end(String callId) async {
    if (!supported) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  /// Android 14+: izin "notifikasi layar penuh" agar layar dering muncul di atas layar kunci.
  static Future<void> requestPermission() async {
    if (!supported) return;
    try {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (_) {}
  }

  /// Teruskan tombol Jawab/Tolak di layar dering ke [onAction] (callId, jawab?).
  static void listen(void Function(String callId, bool accept) onAction) {
    if (!supported || _sub != null) return;
    _sub = FlutterCallkitIncoming.onEvent.listen((e) {
      if (e is ck.CallEventActionCallAccept) {
        final id = e.callKitParams.id;
        if (id.isNotEmpty) onAction(id, true);
      } else if (e is ck.CallEventActionCallDecline) {
        final id = e.callKitParams.id;
        if (id.isNotEmpty) onAction(id, false);
      }
    });
  }

  /// Aplikasi dibuka dari keadaan tertutup lewat tombol Jawab: kembalikan id panggilannya.
  static Future<String?> acceptedOnLaunch() async {
    if (!supported) return null;
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final c in calls) {
        if (c.id.isNotEmpty && c.isAccepted) return c.id;
      }
    } catch (_) {}
    return null;
  }
}
