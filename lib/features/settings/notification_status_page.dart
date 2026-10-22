import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/constants/app_colors.dart';
import '../../core/services/push_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/ui_kit.dart';

/// Memeriksa apakah notifikasi dan pengingat benar-benar sampai ke HP ini:
/// Firebase di aplikasi, izin notifikasi, perangkat terdaftar, dan jadwal pengingat otomatis di server.
/// Ada tombol "Kirim notifikasi uji" untuk membuktikan push saat aplikasi tertutup.
class NotificationStatusPage extends StatefulWidget {
  const NotificationStatusPage({super.key});
  @override
  State<NotificationStatusPage> createState() => _NotificationStatusPageState();
}

class _Snapshot {
  const _Snapshot(this.push, this.health, this.healthError);
  final PushStatus push;
  final Map<String, dynamic>? health;
  final String? healthError;
}

class _NotificationStatusPageState extends State<NotificationStatusPage> {
  late Future<_Snapshot> _f = _load();
  bool _sending = false;

  Future<_Snapshot> _load() async {
    final push = await PushService.instance.status();
    Map<String, dynamic>? health;
    String? err;
    try {
      final r = await SupabaseService.client.rpc('reminder_health');
      if (r is Map) health = Map<String, dynamic>.from(r);
    } catch (_) {
      err = 'Fungsi pemeriksaan belum dipasang di database. Jalankan sql/24_notification_health.sql di Supabase.';
    }
    return _Snapshot(push, health, err);
  }

  void _reload() => setState(() => _f = _load());

  Future<void> _askPermission() async {
    await PushService.instance.register();
    if (mounted) _reload();
  }

  Future<void> _sendTest() async {
    setState(() => _sending = true);
    String msg = 'Notifikasi uji dikirim. Tekan Home, lalu tunggu beberapa detik.';
    try {
      await SupabaseService.client.rpc('send_test_notification');
    } on PostgrestException catch (e) {
      msg = e.message.isEmpty ? 'Gagal mengirim notifikasi uji.' : e.message;
    } catch (_) {
      msg = 'Gagal mengirim. Pastikan sql/24_notification_health.sql sudah dijalankan.';
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return 'belum pernah';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month} ${two(d.hour)}.${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi & Pengingat')),
      body: PageGlow(
        accent: AppColors.amber,
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _f;
          },
          child: FutureBuilder<_Snapshot>(
            future: _f,
            builder: (context, snap) {
              if (!snap.hasData) return const SkeletonList(count: 4, height: 72);
              final s = snap.data!;
              final p = s.push;
              final h = s.health;
              final devices = (h?['my_devices'] is num) ? (h!['my_devices'] as num).toInt() : 0;
              final cron = h?['cron_scheduled'] == true;

              final rows = <Widget>[
                _CheckRow(
                  ok: p.configured,
                  title: 'Firebase di aplikasi',
                  detail: p.configured
                      ? 'Terhubung. Aplikasi bisa menerima push.'
                      : 'Belum dikonfigurasi, jadi notifikasi saat aplikasi tertutup belum aktif. Ikuti docs/NOTIFIKASI.md (langkah flutterfire configure).',
                ),
                _CheckRow(
                  ok: !p.configured ? null : (p.permission == 'granted' ? true : (p.permission == 'denied' ? false : null)),
                  title: 'Izin notifikasi',
                  detail: !p.configured
                      ? 'Menunggu Firebase.'
                      : p.permission == 'granted'
                          ? 'Diizinkan.'
                          : p.permission == 'denied'
                              ? 'Ditolak. Buka Pengaturan HP > Aplikasi > PERKAPI > Notifikasi, lalu aktifkan.'
                              : 'Belum diminta.',
                  action: (p.configured && p.permission != 'granted')
                      ? OutlinedButton(onPressed: _askPermission, child: const Text('Minta izin'))
                      : null,
                ),
                _CheckRow(
                  ok: !p.configured ? null : ((p.registered || devices > 0) ? true : false),
                  title: 'HP ini terdaftar di server',
                  detail: !p.configured
                      ? 'Menunggu Firebase.'
                      : (p.registered || devices > 0)
                          ? 'Terdaftar ($devices perangkat pada akun Anda).'
                          : 'Belum terdaftar. Pastikan sql/13_push_tokens.sql sudah dijalankan, lalu keluar dan masuk lagi.',
                ),
                _CheckRow(
                  ok: h == null ? null : cron,
                  title: 'Pengingat otomatis di server',
                  detail: h == null
                      ? (s.healthError ?? 'Tidak dapat memeriksa.')
                      : cron
                          ? 'Aktif, berjalan tiap 15 menit. Terakhir: ${_fmt(h['last_run'])}.'
                          : 'Belum aktif. Supabase Dashboard > Integrations > Cron > Enable, lalu jalankan ulang sql/14 dan sql/24.',
                ),
              ];

              final scheme = Theme.of(context).colorScheme;
              Widget bullet(String t) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                      ),
                      Expanded(child: Text(t, style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface))),
                    ]),
                  );

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                children: [
                  const Reveal(
                    index: 0,
                    dy: -12,
                    child: ScreenHero(
                      title: 'Notifikasi & Pengingat',
                      subtitle: 'Pastikan tenggat sampai ke HP Anda',
                      icon: Icons.notifications_active_rounded,
                      accent: AppColors.amber,
                    ),
                  ),
                  const SectionHeader('Status perangkat ini'),
                  const SizedBox(height: 8),
                  Reveal(
                    index: 1,
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          rows[i],
                          if (i < rows.length - 1) const Divider(height: 1),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Kirim notifikasi uji',
                    icon: Icons.send_rounded,
                    loading: _sending,
                    onPressed: _sending ? null : _sendTest,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Setelah menekan tombol, tekan Home agar aplikasi di latar, lalu tunggu beberapa detik. Notifikasi uji juga muncul di daftar Notifikasi.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SectionHeader('Pengingat yang dikirim otomatis'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      bullet('Event: 24 jam dan 1 jam sebelum mulai (bila RSVP Anda bukan "Tidak").'),
                      bullet('Tugas: jatuh tempo hari ini dan besok.'),
                      bullet('Perkara yang ditugaskan ke Anda: deadline H-3 dan H-1, serta tanggal perkara H-1.'),
                      bullet('Pengingat berbasis tanggal dikirim pukul 07.00-20.00 WIB agar tidak mengganggu malam hari.'),
                      bullet('Tahapan linimasa dan pengingat catatan tampil sebagai Peringatan di dalam aplikasi (belum berupa push).'),
                    ]),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.ok, required this.title, required this.detail, this.action});
  final bool? ok;
  final String title, detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok == true ? AppColors.emerald : (ok == false ? AppColors.red : AppColors.amber);
    final icon = ok == true ? Icons.check_rounded : (ok == false ? Icons.close_rounded : Icons.more_horiz_rounded);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SolidTile(icon: icon, color: color, size: 36, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(detail, style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ]),
        ),
      ]),
    );
  }
}
