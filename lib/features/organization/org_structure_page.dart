import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/tilt_3d.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';

SupabaseClient get _db => SupabaseService.client;

class OrgMember {
  OrgMember(this.row);
  final Map<String, dynamic> row;
  String get id => row['id'] as String;
  String get name => (row['name'] as String?) ?? '';
  String get position => (row['position'] as String?) ?? '';
  String get division => (row['division'] as String?) ?? 'Pengurus Harian';
  int get sortOrder => (row['sort_order'] as num?)?.toInt() ?? 100;
  bool get isLeader => row['is_leader'] == true;
  bool get isActive => row['is_active'] != false;
  String get period => (row['period'] as String?) ?? '';
  String get bio => (row['bio'] as String?) ?? '';
  String? get photoPath => row['photo_path'] as String?;
}

/// Foto pengurus dari bucket publik `org-photos`; jika belum ada atau gagal dimuat tampil inisial.
class OrgPhoto extends StatelessWidget {
  const OrgPhoto({super.key, required this.name, this.path, this.size = 56, this.circle = true});
  final String name;
  final String? path;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final p = path;
    final url = (p == null || p.isEmpty) ? null : _db.storage.from('org-photos').getPublicUrl(p);
    final initial = name.trim().isEmpty ? '?' : String.fromCharCode(name.trim().runes.first).toUpperCase();
    final fallback = Container(
      color: AppColors.navy,
      alignment: Alignment.center,
      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: circle ? size * 0.42 : 72)),
    );
    final img = url == null
        ? fallback
        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    return Semantics(
      image: true,
      label: name.isEmpty ? 'Foto pengurus' : 'Foto $name',
      child: ExcludeSemantics(
        child: circle ? ClipOval(child: SizedBox(width: size, height: size, child: img)) : SizedBox.expand(child: img),
      ),
    );
  }
}

class OrgStructurePage extends StatefulWidget {
  const OrgStructurePage({super.key});
  @override
  State<OrgStructurePage> createState() => _OrgStructurePageState();
}

class _OrgStructurePageState extends State<OrgStructurePage> {
  List<OrgMember>? _items;
  String? _error;
  bool get _canEdit => Access.instance.can('manage_member');

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Access.instance.addListener(_rebuild);
    _load();
  }

  @override
  void dispose() {
    Access.instance.removeListener(_rebuild);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _db.from('org_structure').select().order('sort_order').order('name');
      if (!mounted) return;
      setState(() {
        _items = rows.map((r) => OrgMember(r)).toList();
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat struktur organisasi. Pastikan skrip sql/28_org_structure.sql sudah dijalankan.');
    }
  }

  Future<void> _edit([OrgMember? m]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(item: m),
    );
    if (saved == true) _load();
  }

  void _open(OrgMember m) {
    if (_canEdit) {
      _edit(m);
      return;
    }
    if (m.bio.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(m.position, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navyAction)),
          const SizedBox(height: 12),
          Text(m.bio, style: const TextStyle(height: 1.5)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final items = _items;
    Widget body;
    if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (items == null) {
      body = const SkeletonList();
    } else if (items.isEmpty) {
      body = Column(children: [
        Expanded(child: EmptyState(message: _canEdit ? 'Struktur belum diisi. Ketuk "Tambah pengurus" di bawah.' : 'Struktur organisasi belum diisi pengurus.')),
        if (_canEdit)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom + 70),
            child: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Tambah pengurus')),
          ),
      ]);
    } else {
      final leaders = items.where((m) => m.isLeader && m.isActive).toList();
      final groups = <String, List<OrgMember>>{};
      for (final m in items.where((m) => !m.isLeader)) {
        groups.putIfAbsent(m.division, () => []).add(m);
      }
      body = ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 90 + MediaQuery.paddingOf(context).bottom),
        children: [
          Reveal(
            index: 0,
            dy: -12,
            child: Text('Kepengurusan ${items.first.period}', style: TextStyle(fontWeight: FontWeight.w700, color: sc.onSurfaceVariant)),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Tambah pengurus')),
          ],
          if (leaders.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Coverflow(items: leaders, onTap: _open),
          ],
          if (!_canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text('Struktur ini dikelola admin PERKAPI.', style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant)),
            ),
          for (final e in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 22, bottom: 8),
              child: Row(children: [
                Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.navyAction, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
            for (final m in e.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Tilt3D(
                  maxAngle: 0.08,
                  child: AppCard(
                    onTap: () => _open(m),
                    child: Row(children: [
                      OrgPhoto(name: m.name, path: m.photoPath, size: 56),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 2),
                          Text(m.position, style: TextStyle(color: sc.onSurfaceVariant, height: 1.3)),
                          if (!m.isActive) const Text('Nonaktif', style: TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      if (_canEdit) Icon(Icons.edit_outlined, size: 18, color: sc.onSurfaceVariant),
                    ]),
                  ),
                ),
              ),
          ],
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Struktur Organisasi'),
        actions: [
          if (_canEdit && _error == null) IconButton(tooltip: 'Tambah pengurus', onPressed: () => _edit(), icon: const Icon(Icons.person_add_alt_1_rounded)),
        ],
      ),
      body: PageGlow(accent: AppColors.navyAction, child: body),
    );
  }
}

/// Carousel 3D (cover-flow): kartu pemimpin berputar dengan perspektif saat digeser.
class _Coverflow extends StatefulWidget {
  const _Coverflow({required this.items, required this.onTap});
  final List<OrgMember> items;
  final ValueChanged<OrgMember> onTap;
  @override
  State<_Coverflow> createState() => _CoverflowState();
}

class _CoverflowState extends State<_Coverflow> {
  final _pc = PageController(viewportFraction: 0.64);
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return SizedBox(
      height: 360,
      child: PageView.builder(
        controller: _pc,
        itemCount: widget.items.length,
        itemBuilder: (context, i) => AnimatedBuilder(
          animation: _pc,
          builder: (context, _) {
            var page = 0.0;
            if (_pc.hasClients && _pc.position.haveDimensions) page = _pc.page ?? 0.0;
            final d = (i - page).clamp(-1.0, 1.0);
            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(still ? 0 : -d * 0.7)
              ..scale(1 - d.abs() * 0.14, 1 - d.abs() * 0.14, 1.0);
            return Transform(alignment: Alignment.center, transform: m, child: _LeaderCard(m: widget.items[i], onTap: widget.onTap));
          },
        ),
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.m, required this.onTap});
  final OrgMember m;
  final ValueChanged<OrgMember> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Tilt3D(
        radius: 26,
        child: GestureDetector(
          onTap: () => onTap(m),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: AppColors.navy.withOpacity(0.35), blurRadius: 28, offset: const Offset(0, 14))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(fit: StackFit.expand, children: [
                OrgPhoto(name: m.name, path: m.photoPath, circle: false),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE60F2B5B)]),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.position.toUpperCase(), style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 3),
                    Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.15)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({this.item});
  final OrgMember? item;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _pos = TextEditingController(text: widget.item?.position);
  late final _div = TextEditingController(text: widget.item?.division ?? 'Pengurus Harian');
  late final _sort = TextEditingController(text: '${widget.item?.sortOrder ?? 100}');
  late final _period = TextEditingController(text: widget.item?.period.isNotEmpty == true ? widget.item!.period : '2026-2031');
  late final _bio = TextEditingController(text: widget.item?.bio);
  late bool _leader = widget.item?.isLeader ?? false;
  late bool _active = widget.item?.isActive ?? true;
  Uint8List? _bytes;
  String _ext = 'jpg';
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_name, _pos, _div, _sort, _period, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png'], withData: true);
    final b = res?.files.single.bytes;
    if (b == null) return;
    if (b.length > 2 * 1024 * 1024) {
      setState(() => _err = 'Ukuran foto maksimal 2 MB.');
      return;
    }
    final png = b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final jpg = b.length > 4 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;
    if (!png && !jpg) {
      setState(() => _err = 'File harus berupa foto JPG atau PNG.');
      return;
    }
    setState(() {
      _bytes = b;
      _ext = png ? 'png' : 'jpg';
      _err = null;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim(), pos = _pos.text.trim();
    if (name.isEmpty || pos.isEmpty) {
      setState(() => _err = 'Nama dan jabatan wajib diisi.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final data = {
      'name': name,
      'position': pos,
      'division': _div.text.trim().isEmpty ? 'Pengurus Harian' : _div.text.trim(),
      'sort_order': int.tryParse(_sort.text.trim()) ?? 100,
      'period': _period.text.trim().isEmpty ? '2026-2031' : _period.text.trim(),
      'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
      'is_leader': _leader,
      'is_active': _active,
    };
    try {
      final old = widget.item?.photoPath;
      String id;
      if (widget.item == null) {
        final r = await _db.from('org_structure').insert(data).select('id').single();
        id = r['id'] as String;
      } else {
        id = widget.item!.id;
        await _db.from('org_structure').update(data).eq('id', id);
      }
      final bytes = _bytes;
      if (bytes != null) {
        final path = '$id/photo_${DateTime.now().millisecondsSinceEpoch}.$_ext';
        await _db.storage.from('org-photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _ext == 'png' ? 'image/png' : 'image/jpeg'));
        await _db.from('org_structure').update({'photo_path': path}).eq('id', id);
        if (old != null && old.isNotEmpty) {
          try {
            await _db.storage.from('org-photos').remove([old]);
          } catch (_) {}
        }
      }
      successHaptic();
      if (mounted) Navigator.pop(context, true);
    } on StorageException {
      if (mounted) setState(() => _err = 'Data tersimpan, tetapi foto ditolak. Anda mungkin tidak memiliki izin.');
    } catch (_) {
      if (mounted) setState(() => _err = 'Gagal menyimpan. Periksa izin dan koneksi Anda.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus pengurus?'),
        content: Text('${widget.item!.name} akan dihapus dari struktur organisasi.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus'))],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _db.from('org_structure').delete().eq('id', widget.item!.id);
      final p = widget.item!.photoPath;
      if (p != null && p.isNotEmpty) {
        try {
          await _db.storage.from('org-photos').remove([p]);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() {
            _busy = false;
            _err = 'Gagal menghapus.';
          });
    }
  }

  Widget _field(TextEditingController c, String label, {int lines = 1, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(controller: c, minLines: lines, maxLines: lines, keyboardType: type, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(item == null ? 'Tambah pengurus' : 'Ubah pengurus', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(children: [
            _bytes != null
                ? ClipOval(child: Image.memory(_bytes!, width: 72, height: 72, fit: BoxFit.cover))
                : OrgPhoto(name: _name.text, path: item?.photoPath, size: 72),
            const SizedBox(width: 14),
            OutlinedButton.icon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: Text(_bytes != null || (item?.photoPath ?? '').isNotEmpty ? 'Ganti foto' : 'Pilih foto')),
          ]),
          const SizedBox(height: 4),
          const Text('Foto pengurus tampil juga di situs publik. JPG/PNG, maksimal 2 MB.', style: TextStyle(fontSize: 12)),
          _field(_name, 'Nama lengkap'),
          _field(_pos, 'Jabatan (mis. Ketua Umum)'),
          _field(_div, 'Kelompok (mis. Pengurus Harian, Dewan Pembina)'),
          _field(_sort, 'Urutan (angka kecil tampil lebih awal)', type: TextInputType.number),
          _field(_period, 'Periode'),
          _field(_bio, 'Profil singkat (opsional)', lines: 3),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tampilkan di carousel 3D teratas'), value: _leader, onChanged: (v) => setState(() => _leader = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif (tampil di situs publik)'), value: _active, onChanged: (v) => setState(() => _active = v)),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_err!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          Row(children: [
            if (item != null) TextButton(onPressed: _busy ? null : _delete, child: const Text('Hapus', style: TextStyle(color: AppColors.red))),
            const Spacer(),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Menyimpan...' : 'Simpan')),
          ]),
        ]),
      ),
    );
  }
}
