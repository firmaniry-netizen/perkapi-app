import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';

class SupabaseService {
  SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static Session? get session => client.auth.currentSession;
  static bool get isLoggedIn => session != null;
}
