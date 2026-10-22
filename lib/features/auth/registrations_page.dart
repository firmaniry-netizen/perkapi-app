import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import 'registration_repository.dart';
import '../../core/widgets/smooth_overlays.dart';

/// Persetujuan pendaftaran anggota baru. Hanya untuk admin utama (SUPER_ADMIN).
/// Pemeriksaan sebenarnya ada di database (RPC memeriksa is_super()); ini hanya UX.
class RegistrationsPage extends StatefulWidget {
  const RegistrationsPage({super.key});

  @override
  State<RegistrationsPage> createState() => _RegistrationsPageState();
}

class _RegistrationsPageState extends State<RegistrationsPage> {
  final _repo = RegistrationRepository();
  String _filter = 'pending';
  late Future<List<RegistrationItem>> _future = _repo.list(_filter);
  final Set<String> _busy = {};

  void _reload() => setState(() => _future = _repo.list(_filter));

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _err(Object e) => e is PostgrestException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  Future<void> _approve(RegistrationItem it) async {
    final roles = await _repo.roles();
    if (!mounted) return;
    final res = await showSmoothDialog<_ApproveResult>(
      context: context,
      builder: (_) => _ApproveDialog(name: it.fullName, roles: roles),
    );
    if (res == null) return;
    setState(() => _busy.add(it.id));
    try {
      await _repo.approve(memberId: it.id, roleCode: res.roleCode, memberNumber: res.memberNumber);
      _snack('${it.fullName} disetujui.');
      _reload();
    } catch (e) {
      _snack(_err(e));
    } finally {
      if (mounted) setState(() => _busy.remove(it.id));
    }
  }

  Future<void> _reject(RegistrationItem it) async {
    final reason = await showSmoothDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(name: it.fullName),
    );
    if (reason == null) return;
    setState(() => _busy.add(it.id));
    try {
      await _repo.reject(memberId: it.id, reason: reason);
      _snack('Pendaftaran ${it.fullName} ditolak.');
      _reload();
    } catch (e) {
      _snack(_err(e));
    } finally {
      if (mounted) setState(() => _busy.remove(it.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Access.instance.isSuper) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Persetujuan pendaftaran')),
      body: PageGlow(accent: AppColors.amber, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Menunggu'), icon: Icon(Icons.hourglass_top_rounded)),
                ButtonSegment(value: 'rejected', label: Text('Ditolak'), icon: Icon(Icons.block_outlined)),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                _filter = s.first;
                _reload();
              },
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RegistrationItem>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ErrorState(
                  message: 'Gagal memuat pendaftaran. Pastikan skrip SQL 08 sudah dijalankan.',
                  onRetry: _reload,
                );
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.how_to_reg_outlined,
                  message: _filter == 'pending' ? 'Tidak ada pendaftaran yang menunggu.' : 'Belum ada pendaftaran yang ditolak.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _reload();
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _card(items[i]),
                ),
              );
            },
          ),
        ),
      ])),
    );
  }

  Widget _card(RegistrationItem it) {
    final busy = _busy.contains(it.id);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final date = it.registeredAt == null ? null : DateFormat('dd/MM/yyyy HH:mm').format(it.registeredAt!);
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(color: muted))),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(it.fullName.isEmpty ? it.email : it.fullName,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          StatusChip(it.status == 'pending' ? 'Menunggu' : 'Ditolak'),
        ]),
        line(Icons.mail_outline, it.email),
        if ((it.phone ?? '').isNotEmpty) line(Icons.phone_outlined, it.phone!),
        if ((it.branchName ?? '').isNotEmpty) line(Icons.location_city_outlined, it.branchName!),
        if (date != null) line(Icons.schedule_outlined, 'Mendaftar $date'),
        if (it.status == 'rejected' && (it.rejectionReason ?? '').isNotEmpty)
          line(Icons.info_outline, 'Alasan: ${it.rejectionReason}'),
        const SizedBox(height: 12),
        if (busy)
          const Center(child: Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator()))
        else
          Row(children: [
            if (it.status == 'pending')
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(it),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Tolak'),
                ),
              ),
            if (it.status == 'pending') const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _approve(it),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Setujui'),
              ),
            ),
          ]),
      ]),
    );
  }
}

class _ApproveResult {
  const _ApproveResult(this.roleCode, this.memberNumber);
  final String roleCode;
  final String? memberNumber;
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.name, required this.roles});
  final String name;
  final List<RoleOption> roles;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late String _role = widget.roles.any((r) => r.code == 'ANGGOTA') ? 'ANGGOTA' : widget.roles.first.code;
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setujui pendaftaran'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.name),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [for (final r in widget.roles) DropdownMenuItem(value: r.code, child: Text(r.label))],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            decoration: const InputDecoration(
              labelText: 'Nomor anggota (kosongkan = otomatis)',
              helperText: 'Format otomatis PRK-TAHUN-NNNN. Nomor ini dipakai anggota untuk masuk.',
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ApproveResult(_role, _number.text.trim())),
          child: const Text('Setujui'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.name});
  final String name;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolak pendaftaran'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.name),
        const SizedBox(height: 12),
        TextField(
          controller: _reason,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: const Text('Tolak'),
        ),
      ],
    );
  }
}
