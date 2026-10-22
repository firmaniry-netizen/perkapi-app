import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/state_widgets.dart';

class _Tracked {
  _Tracked(Map<String, dynamic> j)
      : id = '${j['member_id']}',
        name = '${j['name'] ?? 'Anggota'}',
        consent = j['consent'] == true,
        requested = j['track_requested'] == true,
        sos = j['sos'] == true,
        note = j['sos_note'] as String?,
        pos = (j['lat'] is num && j['lng'] is num) ? LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()) : null,
        at = DateTime.tryParse('${j['located_at'] ?? ''}')?.toLocal(),
        checkin = DateTime.tryParse('${j['last_checkin_at'] ?? ''}')?.toLocal();
  final String id, name;
  final bool consent, requested, sos;
  final String? note;
  final LatLng? pos;
  final DateTime? at;
  final DateTime? checkin;
}

/// Hanya admin utama / izin `view_location`. Dijaga di UI DAN di database (RLS + fungsi SECURITY DEFINER).
class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _map = MapController();
  List<_Tracked> _rows = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  RealtimeChannel? _ch;

  bool get _allowed => Access.instance.can('view_location');

  @override
  void initState() {
    super.initState();
    if (!_allowed) return;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
    _ch = SupabaseService.client
        .channel('admin-locations')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'member_locations', callback: (_) => _load())
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ch?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await SupabaseService.client.rpc('admin_tracked_members');
      final list = (r as List).map((e) => _Tracked(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _rows = list; _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal memuat. Pastikan sql/12_gps_tracking.sql sudah dijalankan.'; });
    }
  }

  Future<void> _toggle(_Tracked t) async {
    try {
      final r = await SupabaseService.client.rpc('admin_set_tracking', params: {'p_member': t.id, 'p_on': !t.requested});
      if (!mounted) return;
      if (r == 'no_consent') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anggota belum memberi izin lokasi.')));
      }
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengubah pelacakan.')));
    }
  }

  String _ago(DateTime? d) {
    if (d == null) return 'belum ada lokasi';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'baru saja';
    if (m < 60) return '$m mnt lalu';
    if (m < 1440) return '${m ~/ 60} jam lalu';
    return '${m ~/ 1440} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const AccessDenied();
    final scheme = Theme.of(context).colorScheme;
    final located = _rows.where((r) => r.pos != null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pelacakan GPS'), actions: [
        IconButton(onPressed: () => context.push('/geofences'), icon: const Icon(Icons.pin_drop_outlined), tooltip: 'Area (geofence)'),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Muat ulang'),
      ]),
      body: Column(children: [
        SizedBox(
          height: 300,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: located.isNotEmpty ? located.first.pos! : const LatLng(-2.5, 118),
              initialZoom: located.isNotEmpty ? 13 : 4.5,
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'id.perkapi.app'),
              MarkerLayer(markers: [
                for (final r in located)
                  Marker(
                    point: r.pos!,
                    width: 120,
                    height: 66,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: r.sos ? AppColors.red : AppColors.navy, borderRadius: BorderRadius.circular(10)),
                        child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.location_on, size: 36, color: r.sos ? AppColors.red : const Color(0xFF2456B8)),
                    ]),
                  ),
              ]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                  : _rows.isEmpty
                      ? Center(child: Text('Belum ada anggota yang mengaktifkan izin lokasi atau SOS.', style: TextStyle(color: scheme.onSurfaceVariant)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = _rows[i];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: r.sos ? AppColors.red : scheme.outline, width: r.sos ? 1.6 : 1),
                              ),
                              child: ListTile(
                                onTap: r.pos == null ? null : () => _map.move(r.pos!, 16),
                                leading: Icon(r.sos ? Icons.sos_rounded : Icons.person_pin_circle_outlined, color: r.sos ? AppColors.red : scheme.primary, size: 30),
                                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text(r.sos
                                    ? 'SOS${r.note != null ? ': ${r.note}' : ''} · ${_ago(r.at)}'
                                    : r.requested
                                        ? 'Dilacak · ${_ago(r.at)}'
                                        : r.consent
                                            ? 'Izin diberikan · tidak dilacak${r.checkin != null ? ' · aman ${_ago(r.checkin)}' : ''}'
                                            : 'Check-in aman ${_ago(r.checkin)}'),
                                trailing: r.sos
                                    ? null
                                    : FilledButton.tonal(onPressed: () => _toggle(r), child: Text(r.requested ? 'Henti' : 'Lacak')),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
