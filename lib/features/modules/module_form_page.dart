import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/access_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/services/supabase_service.dart';
import '../members/avatar_editor.dart';
import '../../shared/models/modules.dart';
import '../../shared/repositories/data_repository.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../shared/widgets/markdown_widgets.dart';
import 'module_extras.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/format_id.dart';

/// Form generik create/edit/detail dibangun dari ModuleDef.fields.
class ModuleFormPage extends StatefulWidget {
  const ModuleFormPage({super.key, required this.moduleId, this.rowId});
  final String moduleId;
  final String? rowId; // null = baru

  @override
  State<ModuleFormPage> createState() => _ModuleFormPageState();
}

class _ModuleFormPageState extends State<ModuleFormPage> {
  final _key = GlobalKey<FormState>();
  final Map<String, dynamic> _v = {};
  final Map<String, List<Map<String, dynamic>>> _lookups = {};
  bool _loading = true, _saving = false;
  String? _error;

  ModuleDef? get m => modules[widget.moduleId];
  bool get _isNew => widget.rowId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mod = m;
    if (mod == null) return;
    try {
      for (final f in mod.fields.where((f) => f.type == FieldType.lookup)) {
        _lookups[f.key] = await DataRepository.lookup(f.lookupTable!, f.lookupLabel);
      }
      if (!_isNew) {
        final row = await DataRepository.get(mod, widget.rowId!);
        if (row == null) {
          _error = 'Data tidak ditemukan atau Anda tidak memiliki akses.';
        } else {
          _v.addAll(row);
        }
      } else {
        for (final f in mod.fields) {
          if (f.type == FieldType.select && f.key == 'status' && f.options.isNotEmpty) {
            _v[f.key] = f.options.first;
          }
          if (f.type == FieldType.boolean) _v[f.key] = f.key == 'is_published';
        }
      }
    } on DataException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _payload(ModuleDef mod) {
    final out = <String, dynamic>{};
    for (final f in mod.fields) {
      var v = _v[f.key];
      if (v is String && v.trim().isEmpty) v = null;
      if (f.type == FieldType.number && v is String) v = double.tryParse(v);
      if (f.type == FieldType.tags && v is String) {
        v = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      out[f.key] = v;
    }
    return out;
  }

  Future<void> _save(ModuleDef mod) async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = _payload(mod);
      if (_isNew) {
        await DataRepository.insert(mod, data);
      } else {
        await DataRepository.update(mod, widget.rowId!, data);
      }
      if (!mounted) return;
      _done(true);
    } on DataException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(ModuleDef mod) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus data?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828), minimumSize: const Size(88, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DataRepository.delete(mod, widget.rowId!);
      if (mounted) _done(true);
    } on DataException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _done(bool changed) {
    if (context.canPop()) {
      context.pop(changed);
    } else {
      context.go('/module/${widget.moduleId}');
    }
  }

  Widget _field(FieldDef f, bool enabled) {
    final value = _v[f.key];
    String? req(String? s) => f.required && (s == null || s.trim().isEmpty) ? 'Wajib diisi' : null;
    switch (f.type) {
      case FieldType.boolean:
        return SwitchListTile(
          title: Text(f.label),
          value: value == true,
          onChanged: enabled ? (b) => setState(() => _v[f.key] = b) : null,
        );
      case FieldType.select:
        return DropdownButtonFormField<String>(
          value: f.options.contains(value) ? value as String : null,
          decoration: InputDecoration(labelText: f.label),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: enabled ? (s) => setState(() => _v[f.key] = s) : null,
          validator: req,
        );
      case FieldType.lookup:
        final opts = _lookups[f.key] ?? [];
        final ids = opts.map((e) => e['id']).toSet();
        return DropdownButtonFormField<String>(
          value: ids.contains(value) ? value as String : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [
            for (final o in opts)
              DropdownMenuItem(
                value: o['id'] as String,
                child: Text('${o[f.lookupLabel] ?? '-'}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? (s) => setState(() => _v[f.key] = s) : null,
          validator: req,
        );
      case FieldType.date:
      case FieldType.datetime:
        return _dateField(f, enabled);
      case FieldType.tags:
        final init = value is List ? value.join(', ') : (value?.toString() ?? '');
        return TextFormField(
          initialValue: init,
          enabled: enabled,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (s) => _v[f.key] = s,
        );
      case FieldType.markdown:
        return MarkdownEditor(
          label: f.label,
          initialValue: value?.toString() ?? '',
          enabled: enabled,
          onChanged: (s) => _v[f.key] = s,
        );
      case FieldType.text:
      case FieldType.multiline:
      case FieldType.number:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          enabled: enabled,
          maxLines: f.type == FieldType.multiline ? 6 : 1,
          minLines: f.type == FieldType.multiline ? 3 : 1,
          keyboardType: f.type == FieldType.number
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : null,
          decoration: InputDecoration(labelText: f.label),
          onChanged: (s) => _v[f.key] = s,
          validator: req,
        );
    }
  }

  /// Kolom tanggal / tanggal+jam. Dibungkus FormField supaya "wajib diisi" dan urutan Mulai-Selesai ikut divalidasi.
  Widget _dateField(FieldDef f, bool enabled) {
    final withTime = f.type == FieldType.datetime;
    String? validate(Object? _) {
      final v = _v[f.key];
      if (f.required && (v == null || '$v'.isEmpty)) return 'Wajib diisi';
      if (f.key == 'ends_at' && v != null) {
        final s0 = FmtId.parse(_v['starts_at']);
        final e0 = FmtId.parse(v);
        if (s0 != null && e0 != null && e0.isBefore(s0)) return 'Waktu selesai harus setelah waktu mulai';
      }
      return null;
    }

    Future<void> pick(FormFieldState<Object> state) async {
      final cur = FmtId.parse(_v[f.key]) ?? (f.key == 'ends_at' ? FmtId.parse(_v['starts_at']) : null);
      final now = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: cur ?? now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Pilih tanggal',
        cancelText: 'Batal',
        confirmText: withTime ? 'Lanjut' : 'Pilih',
      );
      if (d == null || !mounted) return;
      if (!withTime) {
        setState(() => _v[f.key] = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
        state.didChange(_v[f.key]);
        return;
      }
      final t = await showTimePicker(
        context: context,
        initialTime: cur != null && FmtId.hasTime(_v[f.key]) ? TimeOfDay.fromDateTime(cur) : const TimeOfDay(hour: 9, minute: 0),
        helpText: 'Pilih jam',
        cancelText: 'Batal',
        confirmText: 'Pilih',
        builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
      );
      if (t == null || !mounted) return;
      setState(() => _v[f.key] = DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc().toIso8601String());
      state.didChange(_v[f.key]);
    }

    return FormField<Object>(
      validator: validate,
      builder: (state) {
        final raw = _v[f.key];
        final dt = FmtId.parse(raw);
        final text = dt == null ? '' : (withTime && FmtId.hasTime(raw) ? FmtId.dayDateTime(dt) : FmtId.dayDate(dt));
        final empty = text.isEmpty;
        return InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: enabled ? () => pick(state) : null,
          child: InputDecorator(
            isEmpty: empty,
            decoration: InputDecoration(
              labelText: f.label,
              hintText: withTime ? 'Pilih tanggal & jam' : 'Pilih tanggal',
              errorText: state.errorText,
              suffixIcon: (!empty && enabled && !f.required)
                  ? IconButton(
                      tooltip: 'Kosongkan',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        setState(() => _v[f.key] = null);
                        state.didChange(null);
                      },
                    )
                  : Icon(withTime ? Icons.event_rounded : Icons.calendar_today_outlined),
            ),
            child: Text(empty ? '' : text),
          ),
        );
      },
    );
  }

  /// Foto anggota di atas form. Anggota boleh mengubah fotonya sendiri; pengelola
  /// anggota (manage_member) boleh mengubah foto siapa pun.
  Widget _memberPhoto(bool canWrite) {
    final self = _v['user_id'] != null && _v['user_id'] == SupabaseService.client.auth.currentUser?.id;
    final path = _v['avatar_path'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Center(
        child: AvatarEditor(
          memberId: widget.rowId!,
          forSelf: self,
          name: (_v['full_name'] ?? '').toString(),
          path: path,
          canEdit: canWrite || self,
          radius: 48,
          onChanged: (p) {
            if (self) Access.instance.setAvatarPath(p);
            setState(() => _v['avatar_path'] = p);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mod = m;
    if (mod == null) return const Scaffold(body: EmptyState(message: 'Modul tidak ditemukan'));
    if (!Access.instance.can(mod.readPerm)) return const AccessDenied();
    final canWrite = !mod.readOnly && Access.instance.can(mod.writePerm);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Tambah ${mod.title}' : mod.title),
        actions: [
          if (!_isNew && canWrite)
            IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(mod)),
        ],
      ),
      body: PageGlow(accent: AppColors.forKey(mod.id), child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!)
              : Form(
                  key: _key,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      Reveal(index: 0, dy: -12, child: ScreenHero(title: _isNew ? 'Tambah ${mod.title}' : mod.title, subtitle: 'Lengkapi data lalu tekan Simpan', icon: mod.icon, accent: AppColors.forKey(mod.id))),
                      const SizedBox(height: 16),
                      if (mod.id == 'members' && !_isNew) _memberPhoto(canWrite),
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          for (var i = 0; i < mod.fields.length; i++) ...[
                            Reveal(index: i, dy: 10, child: _field(mod.fields[i], canWrite && !_saving)),
                            if (i < mod.fields.length - 1) const SizedBox(height: 14),
                          ],
                        ]),
                      ),
                      const SizedBox(height: 18),
                      if (canWrite)
                        PrimaryButton(
                          label: 'Simpan',
                          icon: Icons.check_rounded,
                          loading: _saving,
                          onPressed: _saving ? null : () => _save(mod),
                        ),
                      if (!_isNew) ...moduleExtras(mod.id, widget.rowId!, _v),
                    ],
                  ),
                )),
    );
  }
}
