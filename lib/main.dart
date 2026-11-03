import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/theme.dart';
import 'core/constants/env.dart';
import 'core/services/push_service.dart';
import 'core/services/supabase_service.dart';
import 'features/chat/incoming_call_ui.dart';
import 'firebase_options.dart';

/// Pesan FCM saat aplikasi tertutup/di latar (isolate terpisah).
/// Panggilan masuk → layar dering bawaan Android; panggilan dibatalkan → tutup layar dering.
@pragma('vm:entry-point')
Future<void> _pushLatar(RemoteMessage m) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  await IncomingCallUi.handlePush(m.data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await SupabaseService.init();
  await PushService.initFirebase();
  if (PushService.instance.available) FirebaseMessaging.onBackgroundMessage(_pushLatar);
  runApp(const PerkapiApp());
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Konfigurasi Supabase belum diatur.\n\n'
              'Jalankan dengan:\n'
              'flutter run --dart-define-from-file=env.json',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
