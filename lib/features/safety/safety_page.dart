import 'package:flutter/material.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/page_glow.dart';

import '../../core/constants/app_colors.dart';
import '../tracking/location_service.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Untuk SEMUA anggota: atur izin berbagi lokasi dan tombol darurat (SOS).
class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final _svc = LocationService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_u);
    _svc.refreshState().then((_) => _u());
  }

  @override
  void dispose() {
    _svc.removeListener(_u);
    super.dispose();
  }

  void _u() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal. Periksa koneksi lalu coba lagi.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sos() async {
    final note = TextEditingController();
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kirim SOS?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Admin utama akan diberi tahu dan dapat melihat lokasi Anda sampai SOS dibatalkan.'),
          const SizedBox(height: 12),
          TextField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'Catatan singkat (opsional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kirim SOS'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(() => _svc.triggerSos(note.text.trim().isEmpty ? null : note.text.trim()));
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan & SOS')),
      body: PageGlow(accent: AppColors.red, child: ListView(padding: const EdgeInsets.all(20), children: [
        Reveal(index: 0, dy: -12, child: ScreenHero(title: 'Keamanan & SOS', subtitle: 'Atur izin pelacakan dan tombol darurat', icon: Icons.shield_rounded, accent: AppColors.red)),
        const SizedBox(height: 16),
        if (_svc.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_svc.error!, style: TextStyle(color: scheme.error, height: 1.4)),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Izinkan admin melacak saya bila diperlukan', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Lokasi hanya terkirim saat aplikasi terbuka DAN admin meminta pelacakan, atau saat Anda menekan SOS.'),
                value: _svc.consent,
                onChanged: _busy ? null : (v) => _run(() => _svc.setConsent(v)),
              ),
              const Divider(),
              Text(
                'Hanya admin utama yang dapat melihat lokasi. Mencabut izin menghapus semua data lokasi Anda. '
                'Riwayat lokasi otomatis dihapus setelah 7 hari. Saat pelacakan aktif, notifikasi tetap "PERKAPI membagikan lokasi" tampil dan lokasi terus terkirim walau layar mati.',
                style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
              ),
              if (_svc.sharing)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 10, color: AppColors.red),
                    const SizedBox(width: 8),
                    Text('Lokasi Anda sedang dibagikan ke admin', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                  ]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: _svc.sos
              ? Column(children: [
                  const Icon(Icons.sos_rounded, size: 64, color: AppColors.red),
                  const SizedBox(height: 8),
                  const Text('SOS aktif. Admin melihat lokasi Anda.', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _busy ? null : () => _run(_svc.cancelSos), child: const Text('Batalkan SOS, saya aman')),
                ])
              : GestureDetector(
                  onTap: _busy ? null : _sos,
                  child: Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFFE5384A), AppColors.red]),
                      boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.45), blurRadius: 32, spreadRadius: 4)],
                    ),
                    alignment: Alignment.center,
                    child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(() => _svc.checkIn()),
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(_svc.sos ? 'Saya aman (batalkan SOS)' : 'Saya aman (check-in)'),
          ),
        ),
        const SizedBox(height: 12),
        if (!_svc.sos)
          Text('Tekan hanya saat Anda butuh bantuan.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
      ])),
    );
  }
}
