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

  /// Alamat situs resmi; foto berita situs berjalur "img/..." diambil dari sini.
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://perkapi.or.id');

  /// Server TURN untuk telepon/video call di jaringan yang memblokir koneksi langsung (opsional).
  /// Contoh: flutter build apk --dart-define=TURN_URL=turn:turn.contoh.id:3478 --dart-define=TURN_USER=... --dart-define=TURN_PASS=...
  /// Beberapa alamat dipisah koma. Kosong = hanya STUN (berhasil di sebagian besar jaringan).
  static const turnUrl = String.fromEnvironment('TURN_URL');
  static const turnUser = String.fromEnvironment('TURN_USER');
  static const turnPass = String.fromEnvironment('TURN_PASS');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
