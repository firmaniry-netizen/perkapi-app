import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/theme.dart';
import 'core/constants/env.dart';
import 'core/services/push_service.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await SupabaseService.init();
  await PushService.initFirebase();
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
