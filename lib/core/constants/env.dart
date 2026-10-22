/// Konfigurasi Supabase aplikasi.
///
/// Nilai bawaan di bawah sama dengan env.json dan dengan situs (public/config.js). Keduanya adalah
/// alamat proyek dan *publishable key* yang memang dirancang untuk dipasang di aplikasi/situs publik
/// (data dilindungi oleh aturan RLS di database), jadi aman ditanam di sini. Dengan begitu cukup jalankan
/// `flutter run` tanpa tambahan apa pun.
///
/// Untuk memakai proyek lain (mis. staging), timpa saat menjalankan:
///   flutter run --dart-define-from-file=env.json
///
/// JANGAN pernah menaruh service_role key atau API key AI di sini.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hbrplzdymmwthmbpaese.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_dp2aXxuxgKS5eIM97zm7Kw_pc6yFiqu',
  );

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
