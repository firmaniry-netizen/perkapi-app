import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/repositories/data_repository.dart';
import '../../shared/widgets/state_widgets.dart';

/// Form pengiriman peringatan oleh pengelola (permission: manage_alert).
class AlertComposePage extends StatefulWidget {
  const AlertComposePage({super.key});
  @override
  State<AlertComposePage> createState() => _AlertComposePageState();
}

class _AlertComposePageState extends State<AlertComposePage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _severity = 'info';
  String _targetType = 'all';
  String? _targetId;
  DateTime? _expires;
  bool _saving = false;
  List<Map<String, dynamic>> _options = [];
  String _optionLabel = 'name';

  static const _targets = {
    'all': 'Semua anggota',
    'branch': 'Cabang tertentu',
    'role': 'Role tertentu',
    'member': 'Anggota tertentu',
  };

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadOptions(String type) async {
    _targetId = null;
    _options = [];
    if (type == 'all') {
      setState(() {});
      return;
    }
    final table = type == 'branch' ? 'branches' : (type == 'role' ? 'roles' : 'members');
    _optionLabel = type == 'member' ? 'full_name' : 'name';
    final rows = await DataRepository.lookup(table, _optionLabel);
    if (mounted) setState(() => _options = rows);
  }

  Future<void> _pickExpiry() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _expires ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _expires = d);
  }

  Future<void> _send() async {
    if (!_key.currentState!.validate()) return;
    if (_targetType != 'all' && _targetId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih tujuan peringatan.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.client.from('member_alerts').insert({
        'title': _title.text.trim(),
        'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
        'severity': _severity,
        'target_type': _targetType,
        'target_id': _targetType == 'all' ? null : _targetId,
        'expires_at': _expires == null
            ? null
            : DateTime(_expires!.year, _expires!.month, _expires!.day, 23, 59)
                .toUtc()
                .toIso8601String(),
        'created_by': Access.instance.memberId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Peringatan terkirim.')));
      context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gagal mengirim. Anda mungkin tidak memiliki izin.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Access.instance.can('manage_alert')) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Peringatan')),
      body: Form(
        key: _key,
        child: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Judul peringatan'),
            validator: (s) => (s == null || s.trim().isEmpty) ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _body,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Isi pesan (opsional)'),
          ),
          const SizedBox(height: 16),
          Text('Tingkat', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'info', label: Text('Info'), icon: Icon(Icons.info_outline)),
              ButtonSegment(
                  value: 'warning', label: Text('Peringatan'), icon: Icon(Icons.warning_amber_rounded)),
              ButtonSegment(value: 'urgent', label: Text('Penting'), icon: Icon(Icons.error_outline)),
            ],
            selected: {_severity},
            onSelectionChanged: (s) => setState(() => _severity = s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _targetType,
            decoration: const InputDecoration(labelText: 'Kirim kepada'),
            items: [
              for (final e in _targets.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _targetType = v);
              _loadOptions(v);
            },
          ),
          if (_targetType != 'all') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _options.any((o) => o['id'] == _targetId) ? _targetId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: _targets[_targetType]),
              items: [
                for (final o in _options)
                  DropdownMenuItem(
                    value: o['id'] as String,
                    child: Text('${o[_optionLabel] ?? '-'}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _targetId = v),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickExpiry,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Berlaku sampai (opsional)',
                suffixIcon: _expires == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _expires = null)),
              ),
              child: Text(_expires == null ? 'Tanpa batas waktu' : _expires!.toIso8601String().substring(0, 10)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _send,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Kirim'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Peringatan tampil di aplikasi anggota yang dituju dan juga masuk ke menu Notifikasi.',
            style: TextStyle(fontSize: 12),
          ),
        ]),
      ),
    );
  }
}
