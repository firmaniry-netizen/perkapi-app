import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../app/theme_controller.dart';
import '../../core/services/pin_service.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/perkapi_mark.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/services/supabase_service.dart';
import '../auth/auth_repository.dart';
import '../legal/privacy_policy_page.dart';
import 'pin_widgets.dart';
import '../../core/widgets/smooth_overlays.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _storage = FlutterSecureStorage();
  bool _bio = false;
  bool _pin = false;

  @override
  void initState() {
    super.initState();
    _storage.read(key: 'biometric_lock').then((v) {
      if (mounted) setState(() => _bio = v == '1');
    });
    PinService.isEnabled().then((v) {
      if (mounted) setState(() => _pin = v);
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggleBio(bool on) async {
    if (on) {
      try {
        final auth = LocalAuthentication();
        if (!await auth.isDeviceSupported()) {
          _snack('Perangkat tidak mendukung biometrik/kunci layar.');
          return;
        }
        if (!await auth.authenticate(localizedReason: 'Aktifkan kunci aplikasi')) return;
      } catch (_) {
        _snack('Tidak dapat mengaktifkan biometrik.');
        return;
      }
    }
    await _storage.write(key: 'biometric_lock', value: on ? '1' : '0');
    setState(() => _bio = on);
  }

  Future<void> _togglePin(bool on) async {
    if (on) {
      final pin = await showPinSetupDialog(context);
      if (pin == null) return;
      await PinService.setPin(pin);
      if (mounted) setState(() => _pin = true);
      _snack('PIN aktif. Aplikasi akan meminta PIN saat dibuka.');
    } else {
      if (!await showPinConfirmDialog(context)) return;
      await PinService.clear();
      if (mounted) setState(() => _pin = false);
      _snack('PIN dinonaktifkan.');
    }
  }

  Future<void> _changePassword() async {
    final c = TextEditingController();
    final pw = await showSmoothDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Ganti password'),
        content: TextField(
            controller: c, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru (min. 8 karakter)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(d, c.text),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (pw == null) return;
    if (pw.length < 8) {
      _snack('Password minimal 8 karakter.');
      return;
    }
    try {
      await SupabaseService.client.auth.updateUser(UserAttributes(password: pw));
      _snack('Password berhasil diganti.');
    } catch (_) {
      _snack('Gagal mengganti password.');
    }
  }

  Future<void> _deleteAccount() async {
    final c = TextEditingController();
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Hapus akun?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Akun login dan data pribadi Anda (catatan pribadi, percakapan AI, notifikasi, foto profil) '
                'dihapus permanen dan tidak dapat dikembalikan.\n\n'
                'Riwayat forum dan agenda tetap tersimpan tanpa identitas Anda.'),
            const SizedBox(height: 16),
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => set(() {}),
              decoration: const InputDecoration(labelText: 'Ketik HAPUS untuk melanjutkan'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 44),
                backgroundColor: Theme.of(d).colorScheme.error,
                foregroundColor: Theme.of(d).colorScheme.onError,
              ),
              onPressed: c.text.trim().toUpperCase() == 'HAPUS' ? () => Navigator.pop(d, true) : null,
              child: const Text('Hapus akun'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    _snack('Menghapus akun…');
    try {
      await AuthRepository().deleteAccount();
    } on AuthFailure catch (e) {
      _snack(e.message);
    }
  }

  void _info(String title, String body) => showSmoothDialog<void>(
        context: context,
        builder: (d) => AlertDialog(title: Text(title), content: Text(body), actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Tutup'))
        ]),
      );

  Widget _tile(IconData icon, String title, {String? sub, VoidCallback? onTap, Widget? trailing}) => ListTile(
        minTileHeight: 60,
        leading: IconBadge(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: sub == null ? null : Text(sub),
        trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        onTap: onTap,
      );

  Widget _group(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title),
        const SizedBox(height: 8),
        AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: rows)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: PageGlow(accent: AppColors.navyAction, child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(children: [
              const Positioned.fill(child: AuroraBackground(child: SizedBox.shrink())),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Row(children: [
                  PerkapiMark(size: 56, animate: true),
                  SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wordmark(size: 22, color: Colors.white),
                    SizedBox(height: 6),
                    Text('Versi 0.1.0', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          _group('Tampilan', [
            Padding(
              padding: const EdgeInsets.all(12),
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.mode,
                builder: (_, mode, __) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistem')),
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Terang')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Gelap')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (v) => ThemeController.mode.value = v.first,
                  ),
                ),
              ),
            ),
          ]),
          _group('Notifikasi', [
            _tile(Icons.notifications_active_outlined, 'Notifikasi & pengingat',
                sub: 'Cek push, izin, dan kirim notifikasi uji', onTap: () => context.push('/notification-status')),
          ]),
          _group('Keamanan', [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Kunci biometrik / layar', style: TextStyle(fontWeight: FontWeight.w700)),
              value: _bio,
              onChanged: _toggleBio,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.pin_outlined),
              title: const Text('PIN aplikasi (6 digit)', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Dihapus otomatis saat keluar akun'),
              value: _pin,
              onChanged: _togglePin,
            ),
            _tile(Icons.shield_outlined, 'Keamanan & SOS (izin lokasi)', onTap: () => context.push('/safety')),
            _tile(Icons.password, 'Ganti password', onTap: _changePassword),
            _tile(Icons.devices_other, 'Keluar dari semua perangkat', onTap: () => AuthRepository().signOutAll()),
          ]),
          _group('Tentang', [
            _tile(Icons.info_outline, 'Tentang PERKAPI',
                onTap: () => _info('Tentang', 'PERKAPI v0.1.0\nPlatform Digital Organisasi Kurator, Kepailitan & PKPU.\nBukan aplikasi resmi pemerintah.')),
            _tile(Icons.description_outlined, 'Syarat & Ketentuan',
                onTap: () => _info('Syarat & Ketentuan', 'Isi dengan syarat & ketentuan organisasi Anda.')),
            _tile(Icons.privacy_tip_outlined, 'Kebijakan Privasi',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()))),
          ]),
          _group('Akun', [
            _tile(Icons.delete_forever_outlined, 'Hapus akun',
                sub: 'Hapus akun dan data pribadi secara permanen', onTap: _deleteAccount),
          ]),
        ])),
      );
}
