import 'package:flutter/material.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';

/// Check-in GPS. Lokasi hanya diambil SAAT tombol ditekan (tidak ada tracking diam-diam).
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _db = SupabaseService.client;
  List<Map<String, dynamic>> _events = [], _history = [];
  String? _eventId;
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _events = List<Map<String, dynamic>>.from(
          await _db.from('events').select('id,title,starts_at').order('starts_at', ascending: false).limit(50));
      _history = List<Map<String, dynamic>>.from(await _db
          .from('attendance')
          .select('id,event_id,checked_in_at,status,events(title)')
          .eq('member_id', Access.instance.memberId ?? '')
          .order('checked_in_at', ascending: false)
          .limit(30));
    } catch (_) {
      _error = 'Gagal memuat data absensi.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _checkIn() async {
    if (_eventId == null) {
      _snack('Pilih event terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Layanan lokasi (GPS) belum aktif. Aktifkan GPS lalu coba lagi.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        _snack('Izin lokasi ditolak. Check-in memerlukan lokasi Anda saat ini.');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Izin lokasi diblokir. Aktifkan lewat Pengaturan perangkat > Aplikasi > PERKAPI.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _db.from('attendance').insert({
        'event_id': _eventId,
        'member_id': Access.instance.memberId,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'checked_in_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'Hadir',
      });
      _snack('Check-in berhasil.');
      await _load();
    } catch (_) {
      _snack('Check-in gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Absensi & Check-in')),
        body: PageGlow(accent: AppColors.teal, child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
                    Reveal(index: 0, dy: -12, child: ScreenHero(title: 'Absensi & Check-in', subtitle: 'Catat kehadiran dengan lokasi yang aman', icon: Icons.location_on_rounded, accent: AppColors.teal)),
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const IconBadge(Icons.location_on_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Lokasi hanya dibaca saat Anda menekan tombol Check-in.',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _eventId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Pilih event'),
                          items: [
                            for (final e in _events)
                              DropdownMenuItem(value: e['id'] as String, child: Text('${e['title']}', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _eventId = v),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Check-in sekarang',
                          icon: Icons.check_rounded,
                          loading: _busy,
                          onPressed: _busy ? null : _checkIn,
                        ),
                      ]),
                    ),
                    const SectionHeader('Riwayat'),
                    const SizedBox(height: 8),
                    if (_history.isEmpty) const EmptyState(message: 'Belum ada riwayat check-in'),
                    for (final h in _history)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          radius: 20,
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF1B7F4B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${(h['events'] as Map?)?['title'] ?? 'Event'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(fmtValue(h['checked_in_at']),
                                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ]),
                            ),
                            StatusChip('${h['status'] ?? 'Hadir'}'),
                          ]),
                        ),
                      ),
                  ])),
      );
}
