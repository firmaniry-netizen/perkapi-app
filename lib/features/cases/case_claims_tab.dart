import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import '../reports/export_service.dart';
import 'case_models.dart';

const _statuses = ['Diajukan', 'Diakui', 'Bersyarat', 'Dibantah'];
const _types = ['Konkuren', 'Separatis', 'Preferen'];

Color _statusColor(String s) => switch (s) {
      'Diakui' => AppColors.emerald,
      'Bersyarat' => AppColors.amber,
      'Dibantah' => AppColors.red,
      _ => AppColors.navyAction,
    };

/// Jumlah yang dihitung per status: Diakui/Bersyarat memakai jumlah diakui bila diisi.
num _effective(Map<String, dynamic> r) {
  final amount = numOf(r['amount']);
  final rec = r['recognized_amount'];
  return rec == null ? amount : numOf(rec);
}

class ClaimsTab extends StatefulWidget {
  const ClaimsTab({super.key, required this.ctx});
  final CaseContext ctx;
  @override
  State<ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends State<ClaimsTab> with AutomaticKeepAliveClientMixin {
  final _db = SupabaseService.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String? _filter; // status

  @override
  bool get wantKeepAlive => true;

  bool get _canWrite => Access.instance.can('manage_case');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _rows = List<Map<String, dynamic>>.from(
          await _db.from('case_claims').select().eq('case_id', widget.ctx.id).order('creditor_name'));
    } catch (_) {
      _error = 'Gagal memuat tagihan. Pastikan skrip sql/23_case_workbench.sql sudah dijalankan.';
    }
    if (mounted) setState(() => _loading = false);
  }

  // ---------- rekap ----------
  num _sum(Iterable<Map<String, dynamic>> it, num Function(Map<String, dynamic>) f) => it.fold<num>(0, (a, r) => a + f(r));

  Future<void> _edit([Map<String, dynamic>? r]) async {
    final name = TextEditingController(text: '${r?['creditor_name'] ?? ''}');
    final amount = TextEditingController(text: r == null ? '' : '${numOf(r['amount']).round()}');
    final rec = TextEditingController(text: r?['recognized_amount'] == null ? '' : '${numOf(r!['recognized_amount']).round()}');
    final notes = TextEditingController(text: '${r?['notes'] ?? ''}');
    var type = '${r?['claim_type'] ?? 'Konkuren'}';
    var status = '${r?['status'] ?? 'Diajukan'}';
    String? creditorId = r?['creditor_id'] as String?;
    final creditors = widget.ctx.creditors;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(r == null ? 'Tambah tagihan' : 'Ubah tagihan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (creditors.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  value: creditors.any((c) => c['id'] == creditorId) ? creditorId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pilih dari daftar kreditur'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Ketik nama sendiri')),
                    for (final c in creditors) DropdownMenuItem<String?>(value: c['id'] as String, child: Text('${c['name']}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setD(() {
                    creditorId = v;
                    if (v != null) name.text = '${creditors.firstWhere((c) => c['id'] == v)['name']}';
                  }),
                ),
                const SizedBox(height: 12),
              ],
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama kreditur')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Jenis tagihan'),
                items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
                onChanged: (v) => setD(() => type = v ?? type),
              ),
              const SizedBox(height: 12),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah tagihan diajukan (Rp)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [for (final s in _statuses) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setD(() => status = v ?? status),
              ),
              if (status == 'Diakui' || status == 'Bersyarat') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: rec,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah diakui (Rp)', helperText: 'Kosongkan = sama dengan jumlah diajukan'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
            ]),
          ),
          actions: [
            if (r != null)
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.red),
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _delete(r);
                  },
                  child: const Text('Hapus')),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final a = parseRupiah(amount.text);
    final rcRaw = rec.text.trim();
    final rc = parseRupiah(rcRaw);
    final nt = notes.text.trim();
    name.dispose();
    amount.dispose();
    rec.dispose();
    notes.dispose();
    if (ok != true) return;
    if (n.isEmpty || a == null) {
      _snack('Nama kreditur dan jumlah tagihan wajib diisi.');
      return;
    }
    final data = {
      'creditor_id': creditorId,
      'creditor_name': n,
      'claim_type': type,
      'amount': a,
      'status': status,
      'recognized_amount': (status == 'Diakui' || status == 'Bersyarat') && rcRaw.isNotEmpty ? rc : null,
      'notes': nt.isEmpty ? null : nt,
    };
    try {
      if (r == null) {
        await _db.from('case_claims').insert({...data, 'case_id': widget.ctx.id, 'created_by': Access.instance.memberId});
      } else {
        await _db.from('case_claims').update(data).eq('id', r['id']);
      }
      await _load();
    } catch (_) {
      _snack('Gagal menyimpan. Anda memerlukan hak kelola perkara.');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    try {
      await _db.from('case_claims').delete().eq('id', r['id']);
      await _load();
    } catch (_) {
      _snack('Gagal menghapus.');
    }
  }

  /// Buat baris tagihan (jumlah 0, status Diajukan) untuk kreditur perkara ini yang belum punya tagihan.
  Future<void> _importCreditors() async {
    final have = {for (final r in _rows) if (r['creditor_id'] != null) r['creditor_id']};
    final add = [for (final c in widget.ctx.creditors) if (!have.contains(c['id'])) c];
    if (add.isEmpty) {
      _snack('Semua kreditur pada perkara ini sudah punya tagihan.');
      return;
    }
    try {
      await _db.from('case_claims').insert([
        for (final c in add)
          {
            'case_id': widget.ctx.id,
            'creditor_id': c['id'],
            'creditor_name': '${c['name'] ?? '-'}',
            'amount': 0,
            'created_by': Access.instance.memberId,
          },
      ]);
      _snack('${add.length} kreditur ditambahkan. Isi jumlah tagihannya.');
      await _load();
    } catch (_) {
      _snack('Gagal mengimpor kreditur.');
    }
  }

  // ---------- ekspor ----------
  List<List<Object?>> _exportRows({required bool pretty}) {
    String m(num v) => pretty ? rp(v) : '${v.round()}';
    final out = <List<Object?>>[];
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final st = '${r['status']}';
      out.add([
        i + 1,
        r['creditor_name'],
        r['claim_type'],
        m(numOf(r['amount'])),
        (st == 'Diakui' || st == 'Bersyarat') ? m(_effective(r)) : (pretty ? '-' : ''),
        st,
        r['notes'] ?? '',
      ]);
    }
    final dia = _sum(_rows.where((r) => r['status'] == 'Diakui'), _effective);
    out.add(['', 'TOTAL', '', m(_sum(_rows, (r) => numOf(r['amount']))), m(dia), '', 'Total diakui hanya status Diakui']);
    return out;
  }

  Future<void> _export(bool pdf) async {
    if (_rows.isEmpty) {
      _snack('Belum ada tagihan untuk diekspor.');
      return;
    }
    const header = ['No', 'Kreditur', 'Jenis', 'Diajukan', 'Diakui', 'Status', 'Catatan'];
    final name = 'Tagihan_${widget.ctx.number.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}';
    try {
      if (pdf) {
        await ExportService.sharePdf(name, 'Daftar Tagihan Kreditur - ${widget.ctx.number} - ${widget.ctx.title}', header, _exportRows(pretty: true));
      } else {
        await ExportService.shareCsv(name, header, _exportRows(pretty: false));
      }
    } catch (_) {
      _snack('Gagal membuat berkas ekspor.');
    }
  }

  // ---------- tampilan ----------
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const SkeletonList(count: 4, height: 84);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final sc = Theme.of(context).colorScheme;
    final shown = _filter == null ? _rows : _rows.where((r) => r['status'] == _filter).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + MediaQuery.paddingOf(context).bottom), children: [
        _summary(context),
        const SizedBox(height: 12),
        Row(children: [
          if (_canWrite) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(width: 10),
          ],
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'csv') _export(false);
              if (v == 'pdf') _export(true);
              if (v == 'import') _importCreditors();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'csv', child: Text('Ekspor Excel (CSV)')),
              const PopupMenuItem(value: 'pdf', child: Text('Ekspor PDF')),
              if (_canWrite && widget.ctx.creditors.isNotEmpty) const PopupMenuItem(value: 'import', child: Text('Impor dari daftar kreditur')),
            ],
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in [null, ..._statuses])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s == null ? 'Semua (${_rows.length})' : '$s (${_rows.where((r) => r['status'] == s).length})'),
                  selected: _filter == s,
                  selectedColor: s == null ? AppColors.navy : _statusColor(s),
                  labelStyle: TextStyle(color: _filter == s ? Colors.white : null, fontWeight: FontWeight.w700),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _filter = s),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const EmptyState(message: 'Belum ada tagihan.\nTambah satu per satu atau impor dari daftar kreditur.', icon: Icons.request_quote_outlined),
        for (var i = 0; i < shown.length; i++)
          Reveal(
            index: i % 8,
            dy: 10,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tile(shown[i], sc),
            ),
          ),
      ]),
    );
  }

  Widget _summary(BuildContext context) {
    final total = _sum(_rows, (r) => numOf(r['amount']));
    final dia = _sum(_rows.where((r) => r['status'] == 'Diakui'), _effective);
    final bers = _sum(_rows.where((r) => r['status'] == 'Bersyarat'), _effective);
    final bant = _sum(_rows.where((r) => r['status'] == 'Dibantah'), (r) => numOf(r['amount']));
    final pend = _sum(_rows.where((r) => r['status'] == 'Diajukan'), (r) => numOf(r['amount']));
    Widget cell(String label, num v, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 3),
            Text(rp(v), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.navyDeep, AppColors.navy, Color(0xFF1B4A9C)]),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.24), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_rows.length} tagihan  •  total diajukan', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
        const SizedBox(height: 4),
        Text(rp(total), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Row(children: [cell('Diakui', dia, const Color(0xFF5CE08A)), cell('Bersyarat', bers, const Color(0xFFFFC857))]),
        const SizedBox(height: 10),
        Row(children: [cell('Dibantah', bant, const Color(0xFFFF6B73)), cell('Belum diputuskan', pend, const Color(0xFF7FB2FF))]),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (final t in _types)
            Text('$t diakui: ${rp(_sum(_rows.where((r) => r['status'] == 'Diakui' && r['claim_type'] == t), _effective))}',
                style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> r, ColorScheme sc) {
    final st = '${r['status']}';
    final c = _statusColor(st);
    final amount = numOf(r['amount']);
    final showRec = (st == 'Diakui' || st == 'Bersyarat') && r['recognized_amount'] != null && numOf(r['recognized_amount']) != amount;
    final notes = '${r['notes'] ?? ''}'.trim();
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: _canWrite ? () => _edit(r) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${r['creditor_name']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: c.withValues(alpha: 0.35))),
            child: Text(st, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(rp(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (showRec) Text('   diakui ${rp(numOf(r['recognized_amount']))}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
          const Spacer(),
          Text('${r['claim_type']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc.onSurfaceVariant)),
        ]),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(notes, style: TextStyle(fontSize: 13, height: 1.35, color: sc.onSurfaceVariant)),
        ],
      ]),
    );
  }
}
