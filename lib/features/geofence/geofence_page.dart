import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/icon_badge.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Admin: kelola area. Anggota yang sedang dilacak dan keluar/masuk area akan memicu notifikasi ke admin utama.
class GeofencePage extends StatefulWidget {
  const GeofencePage({super.key});
  @override
  State<GeofencePage> createState() => _GeofencePageState();
}

class _GeofencePageState extends State<GeofencePage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  bool get _allowed => Access.instance.can('view_location');

  @override
  void initState() {
    super.initState();
    if (_allowed) _load();
  }

  Future<void> _load() async {
    try {
      final r = await SupabaseService.client.from('geofences').select().order('created_at');
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(r as List); _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal memuat. Jalankan sql/14_geofence_broadcast_reminders_reports.sql.'; });
    }
  }

  Future<void> _edit([Map<String, dynamic>? g]) async {
    final name = TextEditingController(text: g?['name'] as String? ?? '');
    final lat = TextEditingController(text: g == null ? '' : '${g['lat']}');
    final lng = TextEditingController(text: g == null ? '' : '${g['lng']}');
    final rad = TextEditingController(text: g == null ? '300' : '${g['radius_m']}');
    String? err;
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(g == null ? 'Tambah area' : 'Ubah area'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama area')),
              TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude')),
              TextField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude')),
              TextField(controller: rad, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Radius (meter, 50 sampai 50000)')),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.my_location),
                label: const Text('Pakai lokasi saya sekarang'),
                onPressed: () async {
                  try {
                    var p = await Geolocator.checkPermission();
                    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
                    final pos = await Geolocator.getCurrentPosition();
                    lat.text = pos.latitude.toStringAsFixed(6);
                    lng.text = pos.longitude.toStringAsFixed(6);
                    setD(() => err = null);
                  } catch (_) {
                    setD(() => err = 'Tidak bisa membaca lokasi. Isi manual.');
                  }
                },
              ),
              if (err != null) Text(err!, style: TextStyle(color: Theme.of(c).colorScheme.error)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final la = double.tryParse(lat.text.replaceAll(',', '.'));
      final lo = double.tryParse(lng.text.replaceAll(',', '.'));
      final ra = int.tryParse(rad.text);
      if (la == null || lo == null || ra == null || ra < 50 || ra > 50000 || name.text.trim().isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data tidak valid.')));
      } else {
        try {
          await SupabaseService.client.rpc('admin_save_geofence', params: {
            'p_id': g?['id'], 'p_name': name.text.trim(), 'p_lat': la, 'p_lng': lo, 'p_radius': ra, 'p_active': g?['active'] ?? true,
          });
          await _load();
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan.')));
        }
      }
    }
    name.dispose(); lat.dispose(); lng.dispose(); rad.dispose();
  }

  Future<void> _toggle(Map<String, dynamic> g, bool v) async {
    try {
      await SupabaseService.client.rpc('admin_save_geofence', params: {
        'p_id': g['id'], 'p_name': g['name'], 'p_lat': g['lat'], 'p_lng': g['lng'], 'p_radius': g['radius_m'], 'p_active': v,
      });
      await _load();
    } catch (_) {}
  }

  Future<void> _delete(Map<String, dynamic> g) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus area?'),
        content: Text('Area "${g['name']}" akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SupabaseService.client.rpc('admin_delete_geofence', params: {'p_id': g['id']});
        await _load();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Area (Geofence)')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Tambah area')),
      body: PageGlow(accent: AppColors.teal, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _rows.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada area. Tambahkan satu untuk mendapat notifikasi saat anggota yang dilacak keluar atau masuk area.', textAlign: TextAlign.center)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final g = _rows[i];
                        return Card(
                          child: ListTile(
                            onTap: () => _edit(g),
                            leading: const IconBadge(Icons.pin_drop_outlined, size: 44),
                            title: Text('${g['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('Radius ${g['radius_m']} m · ${(g['lat'] as num).toStringAsFixed(4)}, ${(g['lng'] as num).toStringAsFixed(4)}'),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Switch(value: g['active'] == true, onChanged: (v) => _toggle(g, v)),
                              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(g)),
                            ]),
                          ),
                        );
                      },
                    )),
    );
  }
}
