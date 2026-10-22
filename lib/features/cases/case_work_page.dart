import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import 'case_claims_tab.dart';
import 'case_letters.dart';
import 'case_letter_form.dart';
import 'case_models.dart';

/// Ruang kerja satu perkara: Linimasa tahapan, Tagihan kreditur, dan Surat otomatis.
class CaseWorkPage extends StatefulWidget {
  const CaseWorkPage({super.key, required this.caseId});
  final String caseId;
  @override
  State<CaseWorkPage> createState() => _CaseWorkPageState();
}

class _CaseWorkPageState extends State<CaseWorkPage> {
  late Future<CaseContext> _f = CaseContext.load(widget.caseId);

  void _reload() => setState(() => _f = CaseContext.load(widget.caseId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CaseContext>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(appBar: AppBar(title: const Text('Ruang kerja perkara')), body: const SkeletonList());
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ruang kerja perkara')),
            body: ErrorState(message: 'Gagal memuat perkara. Periksa koneksi atau hak akses Anda.', onRetry: _reload),
          );
        }
        final c = snap.data!;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(c.number.isEmpty ? 'Ruang kerja perkara' : c.number, overflow: TextOverflow.ellipsis),
              bottom: const TabBar(tabs: [
                Tab(icon: Icon(Icons.timeline_rounded), text: 'Linimasa'),
                Tab(icon: Icon(Icons.request_quote_outlined), text: 'Tagihan'),
                Tab(icon: Icon(Icons.description_outlined), text: 'Surat'),
              ]),
            ),
            body: PageGlow(accent: AppColors.navyAction, child: Column(children: [
              _header(context, c),
              Expanded(
                child: TabBarView(children: [
                  StagesTab(ctx: c),
                  ClaimsTab(ctx: c),
                  _LettersTab(ctx: c),
                ]),
              ),
            ])),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, CaseContext c) {
    final sc = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.gavel_rounded, color: AppColors.navy, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text('${c.type}  •  ${c.court.isEmpty ? 'Pengadilan belum diisi' : c.court}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: sc.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

// ============================ LINIMASA ============================

class _StageTemplate {
  const _StageTemplate(this.title, [this.offsetDays]);
  final String title;
  final int? offsetDays; // hari setelah tanggal putusan; null = isi manual
}

// Tanggal otomatis HANYA untuk batas yang disebut UU 37/2004 dan wajib dicocokkan:
// Pasal 15 ayat 4 (pengumuman 5 hari), Pasal 225 ayat 4 (sidang PKPU sementara maks. 45 hari),
// Pasal 228 ayat 6 (PKPU tetap maks. 270 hari). Tahap lain bergantung penetapan Hakim Pengawas.
const _tplKepailitan = [
  _StageTemplate('Putusan pernyataan pailit', 0),
  _StageTemplate('Pengumuman putusan di Berita Negara dan surat kabar harian', 5),
  _StageTemplate('Penetapan batas pengajuan tagihan dan jadwal rapat oleh Hakim Pengawas'),
  _StageTemplate('Pemberitahuan kepada kreditur'),
  _StageTemplate('Batas akhir pengajuan tagihan'),
  _StageTemplate('Rapat pencocokan piutang (verifikasi tagihan)'),
  _StageTemplate('Penetapan daftar piutang tetap'),
  _StageTemplate('Rapat kreditur / pembahasan perdamaian'),
  _StageTemplate('Insolvensi'),
  _StageTemplate('Pemberesan dan pembagian harta pailit'),
  _StageTemplate('Pengakhiran kepailitan'),
];

const _tplPkpu = [
  _StageTemplate('Putusan PKPU Sementara', 0),
  _StageTemplate('Pengumuman putusan PKPU'),
  _StageTemplate('Batas akhir pengajuan tagihan'),
  _StageTemplate('Rapat pencocokan piutang'),
  _StageTemplate('Sidang akhir PKPU Sementara / pemungutan suara (maks. 45 hari)', 45),
  _StageTemplate('Pembahasan rencana perdamaian'),
  _StageTemplate('Batas akhir PKPU Tetap termasuk perpanjangan (maks. 270 hari)', 270),
  _StageTemplate('Pengesahan perdamaian (homologasi)'),
];

class StagesTab extends StatefulWidget {
  const StagesTab({super.key, required this.ctx});
  final CaseContext ctx;
  @override
  State<StagesTab> createState() => _StagesTabState();
}

class _StagesTabState extends State<StagesTab> with AutomaticKeepAliveClientMixin {
  final _db = SupabaseService.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

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
      _rows = List<Map<String, dynamic>>.from(await _db
          .from('case_stages')
          .select()
          .eq('case_id', widget.ctx.id)
          .order('sort_order')
          .order('due_date', ascending: true, nullsFirst: false));
    } catch (_) {
      _error = 'Gagal memuat linimasa. Pastikan skrip sql/23_case_workbench.sql sudah dijalankan.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Map<String, dynamic> r) async {
    final done = r['done_at'] != null;
    try {
      await _db.from('case_stages').update({'done_at': done ? null : isoDate(today())}).eq('id', r['id']);
      await _load();
    } catch (_) {
      _snack('Gagal menyimpan. Anda memerlukan hak kelola perkara.');
    }
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus tahapan?'),
        content: Text('${r['title']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('case_stages').delete().eq('id', r['id']);
      await _load();
    } catch (_) {
      _snack('Gagal menghapus.');
    }
  }

  Future<void> _edit([Map<String, dynamic>? r]) async {
    final title = TextEditingController(text: '${r?['title'] ?? ''}');
    final notes = TextEditingController(text: '${r?['notes'] ?? ''}');
    DateTime? due = parseDate(r?['due_date']);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(r == null ? 'Tambah tahapan' : 'Ubah tahapan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nama tahapan')),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: due ?? today(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setD(() => due = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal / batas waktu',
                    prefixIcon: const Icon(Icons.event_outlined),
                    suffixIcon: due == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setD(() => due = null)),
                  ),
                  child: Text(due == null ? 'Belum ditentukan' : dmy(isoDate(due!))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    final t = title.text.trim();
    final n = notes.text.trim();
    title.dispose();
    notes.dispose();
    if (saved != true) return;
    if (t.isEmpty) {
      _snack('Nama tahapan wajib diisi.');
      return;
    }
    final data = {'title': t, 'due_date': due == null ? null : isoDate(due!), 'notes': n.isEmpty ? null : n};
    try {
      if (r == null) {
        final next = _rows.isEmpty ? 0 : (_rows.map((e) => (e['sort_order'] as num?) ?? 0).reduce((a, b) => a > b ? a : b).toInt() + 1);
        await _db.from('case_stages').insert({
          ...data,
          'case_id': widget.ctx.id,
          'sort_order': next,
          'created_by': Access.instance.memberId,
        });
      } else {
        await _db.from('case_stages').update(data).eq('id', r['id']);
      }
      await _load();
    } catch (_) {
      _snack('Gagal menyimpan. Anda memerlukan hak kelola perkara.');
    }
  }

  Future<void> _fromTemplate() async {
    var pkpu = widget.ctx.type.toUpperCase().contains('PKPU');
    DateTime base = widget.ctx.caseDate ?? today();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Isi dari template'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Kepailitan')), ButtonSegment(value: true, label: Text('PKPU'))],
                selected: {pkpu},
                onSelectionChanged: (s) => setD(() => pkpu = s.first),
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: base, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setD(() => base = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal putusan', prefixIcon: Icon(Icons.event_outlined)),
                  child: Text(dmy(isoDate(base))),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tanggal terisi otomatis hanya untuk batas yang tercantum di UU 37/2004: pengumuman putusan pailit 5 hari (Pasal 15 ayat 4), '
                'sidang PKPU Sementara maks. 45 hari (Pasal 225 ayat 4), PKPU Tetap maks. 270 hari (Pasal 228 ayat 6). '
                'Cocokkan dengan undang-undang dan penetapan Hakim Pengawas; tahap lain isi sendiri.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buat tahapan')),
          ],
        ),
      ),
    );
    if (go != true) return;
    final tpl = pkpu ? _tplPkpu : _tplKepailitan;
    final start = _rows.isEmpty ? 0 : (_rows.map((e) => (e['sort_order'] as num?) ?? 0).reduce((a, b) => a > b ? a : b).toInt() + 1);
    try {
      await _db.from('case_stages').insert([
        for (var i = 0; i < tpl.length; i++)
          {
            'case_id': widget.ctx.id,
            'title': tpl[i].title,
            'due_date': tpl[i].offsetDays == null ? null : isoDate(base.add(Duration(days: tpl[i].offsetDays!))),
            'sort_order': start + i,
            'created_by': Access.instance.memberId,
          },
      ]);
      await _load();
    } catch (_) {
      _snack('Gagal membuat tahapan. Anda memerlukan hak kelola perkara.');
    }
  }

  /// (label, warna, ikon) menurut status tahapan.
  (String, Color, IconData) _status(Map<String, dynamic> r) {
    if (r['done_at'] != null) return ('Selesai ${dmy(r['done_at'])}', AppColors.emerald, Icons.check_circle_rounded);
    final due = parseDate(r['due_date']);
    if (due == null) return ('Tanggal belum ditentukan', AppColors.muted, Icons.radio_button_unchecked);
    final diff = due.difference(today()).inDays;
    if (diff < 0) return ('Terlambat ${-diff} hari', AppColors.red, Icons.error_rounded);
    if (diff == 0) return ('Hari ini', AppColors.orange, Icons.notifications_active_rounded);
    if (diff <= 3) return ('H-$diff', AppColors.amber, Icons.schedule_rounded);
    return ('$diff hari lagi', AppColors.navyAction, Icons.radio_button_unchecked);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const SkeletonList(count: 4, height: 84);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final sc = Theme.of(context).colorScheme;
    final done = _rows.where((r) => r['done_at'] != null).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + MediaQuery.paddingOf(context).bottom), children: [
        if (_rows.isNotEmpty) ...[
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$done dari ${_rows.length} tahapan selesai', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: _rows.isEmpty ? 0 : done / _rows.length, minHeight: 8, color: AppColors.emerald),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (_canWrite)
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _fromTemplate,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Dari template'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ]),
        const SizedBox(height: 14),
        if (_rows.isEmpty)
          const EmptyState(message: 'Belum ada tahapan.\nGunakan template Kepailitan/PKPU atau tambah sendiri.', icon: Icons.timeline_rounded),
        for (var i = 0; i < _rows.length; i++)
          Reveal(
            index: i % 8,
            dy: 10,
            child: _tile(_rows[i], first: i == 0, last: i == _rows.length - 1, sc: sc),
          ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> r, {required bool first, required bool last, required ColorScheme sc}) {
    final (label, color, icon) = _status(r);
    final done = r['done_at'] != null;
    final notes = '${r['notes'] ?? ''}'.trim();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 36,
          child: Column(children: [
            Expanded(flex: 1, child: Container(width: 2, color: first ? Colors.transparent : sc.outlineVariant)),
            Icon(icon, color: color, size: 22),
            Expanded(flex: 3, child: Container(width: 2, color: last ? Colors.transparent : sc.outlineVariant)),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              onTap: _canWrite ? () => _edit(r) : null,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${r['title']}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            decoration: done ? TextDecoration.lineThrough : null,
                            color: done ? sc.onSurfaceVariant : null)),
                    const SizedBox(height: 4),
                    Text(
                      r['due_date'] == null ? label : '${dmy(r['due_date'])}  •  $label',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(notes, style: TextStyle(fontSize: 13, height: 1.35, color: sc.onSurfaceVariant)),
                    ],
                  ]),
                ),
                if (_canWrite)
                  PopupMenuButton<String>(
                    tooltip: 'Aksi',
                    onSelected: (v) => v == 'toggle' ? _toggle(r) : v == 'edit' ? _edit(r) : _delete(r),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'toggle', child: Text(done ? 'Tandai belum selesai' : 'Tandai selesai')),
                      const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                      const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ============================ SURAT ============================

class _LettersTab extends StatelessWidget {
  const _LettersTab({required this.ctx});
  final CaseContext ctx;

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    const items = <(LetterKind, IconData, String)>[
      (LetterKind.undangan, Icons.groups_rounded, 'Undangan Rapat Kreditur'),
      (LetterKind.pemberitahuan, Icons.campaign_rounded, 'Pemberitahuan dan Permintaan Pengajuan Tagihan'),
      (LetterKind.beritaAcara, Icons.fact_check_rounded, 'Berita Acara Rapat Kreditur'),
    ];
    return ListView(padding: EdgeInsets.fromLTRB(20, 8, 20, 120 + MediaQuery.paddingOf(context).bottom), children: [
      Text(
        'Surat terisi otomatis dari data perkara, debitur, kreditur, dan ${ctx.officerName}. Hasilnya PDF yang bisa dibagikan. '
        'Isi adalah draf umum: periksa dan sesuaikan sebelum dikirim.',
        style: TextStyle(fontSize: 13, height: 1.45, color: sc.onSurfaceVariant),
      ),
      const SizedBox(height: 14),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            radius: 20,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseLetterForm(ctx: ctx, kind: it.$1))),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(it.$2, color: AppColors.navy),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(it.$3, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.3))),
              Icon(Icons.chevron_right, color: sc.onSurfaceVariant),
            ]),
          ),
        ),
    ]);
  }
}
