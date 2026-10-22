import 'package:flutter/material.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Admin utama: satu pesan ke semua anggota atau satu cabang. Terkirim sebagai notifikasi (dan push bila Firebase aktif).
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});
  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _branches = [];
  String? _branch;
  bool _sending = false;

  bool get _allowed => Access.instance.can('broadcast');

  @override
  void initState() {
    super.initState();
    if (_allowed) _loadBranches();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final r = await SupabaseService.client.from('branches').select('id,name').order('name');
      if (mounted) setState(() => _branches = List<Map<String, dynamic>>.from(r as List));
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul wajib diisi.')));
      return;
    }
    final target = _branch == null
        ? 'SEMUA anggota'
        : 'anggota cabang ${_branches.firstWhere((b) => b['id'] == _branch, orElse: () => {'name': ''})['name']}';
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kirim pengumuman?'),
        content: Text('Pesan akan dikirim ke $target dan tidak bisa ditarik kembali.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final n = await SupabaseService.client.rpc('admin_broadcast',
          params: {'p_title': _title.text.trim(), 'p_body': _body.text.trim(), 'p_branch': _branch});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terkirim ke $n anggota.')));
      _title.clear();
      _body.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim. Pastikan SQL 14 sudah dijalankan.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman Massal')),
      body: PageGlow(accent: AppColors.violet, child: ListView(padding: const EdgeInsets.all(20), children: [
        Reveal(index: 0, dy: -12, child: ScreenHero(title: 'Pengumuman Massal', subtitle: 'Kirim pesan ke seluruh anggota atau satu cabang', icon: Icons.campaign_rounded, accent: AppColors.violet)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: _branch,
          decoration: const InputDecoration(labelText: 'Tujuan'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Semua anggota')),
            for (final b in _branches) DropdownMenuItem<String?>(value: '${b['id']}', child: Text('Cabang ${b['name']}')),
          ],
          onChanged: (v) => setState(() => _branch = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _title, maxLength: 80, decoration: const InputDecoration(labelText: 'Judul')),
        const SizedBox(height: 6),
        TextField(controller: _body, maxLength: 500, maxLines: 5, decoration: const InputDecoration(labelText: 'Isi pesan', alignLabelWithHint: true)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.campaign_outlined),
          label: const Text('Kirim'),
        ),
      ])),
    );
  }
}
