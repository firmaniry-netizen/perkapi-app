import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/ui_kit.dart';
import 'document_signatures.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/upload_helper.dart';
import '../../core/widgets/nav_clearance.dart';

/// Dokumen: bucket privat + signed URL berkedaluwarsa (tidak ada URL publik).
/// Fitur: upload, versi dokumen (riwayat + upload versi baru), ringkasan AI.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  static const _allowed = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'];
  static const _maxBytes = 20 * 1024 * 1024;
  final _db = SupabaseService.client;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _busy = false;
  String? _error;
  String _q = '';

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
      final s = _q.replaceAll(RegExp(r'[,()%*\\.]'), ' ').trim();
      Future<List<dynamic>> run(bool withContent) {
        var qb = _db.from('documents').select();
        if (s.isNotEmpty) {
          qb = withContent ? qb.or('title.ilike.%$s%,content_text.ilike.%$s%') : qb.ilike('title', '%$s%');
        }
        return qb.order('created_at', ascending: false).limit(100);
      }
      List<dynamic> rows;
      try {
        rows = await run(true);
      } catch (_) {
        rows = await run(false); // kolom content_text belum ada: cari judul saja
      }
      _rows = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _error = 'Gagal memuat dokumen atau Anda tidak memiliki akses.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Minta server mengekstrak teks PDF agar isinya bisa dicari. Gagal diam-diam (tidak mengganggu unggahan).
  Future<String?> _indexOne(String id) async {
    try {
      final r = await _db.functions.invoke('index-document', body: {'document_id': id});
      final d = r.data;
      if (d is Map) return d['reason'] as String?;
    } catch (_) {}
    return null;
  }

  Future<void> _reindexAll() async {
    setState(() => _busy = true);
    try {
      final rows = await _db.from('documents').select('id').filter('content_indexed_at', 'is', null).limit(200);
      final ids = [for (final r in rows as List) '${r['id']}'];
      var ok = 0, noText = 0;
      for (final id in ids) {
        final reason = await _indexOne(id);
        if (reason == 'ok') ok++;
        if (reason == 'no_text_layer') noText++;
      }
      _snack('Selesai: $ok PDF terindeks, $noText tanpa teks (hasil pindai), dari ${ids.length} dokumen.');
    } catch (_) {
      _snack('Gagal mengindeks. Pastikan SQL 17 dijalankan dan fungsi index-document sudah di-deploy.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// kind: 'file' (PDF/Word/Excel/gambar), 'gallery' (satu foto dari galeri), 'camera' (foto baru).
  Future<PlatformFile?> _pick({String kind = 'file'}) async {
    try {
      PlatformFile? f;
      if (kind == 'file') {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: _allowed,
          withData: pickWithData,
        );
        f = (res == null || res.files.isEmpty) ? null : res.files.first;
      } else {
        // Foto diperkecil di sisi native (lihat upload_helper) agar HP RAM kecil tidak menutup aplikasi.
        final got = await pickPhotos(camera: kind == 'camera', multiple: false);
        f = got.isEmpty ? null : got.first;
      }
      if (f == null || !hasSource(f)) return null;
      if (f.size > _maxBytes) {
        _snack('Ukuran file maksimal 20 MB.');
        return null;
      }
      return f;
    } catch (e) {
      _snack('Tidak bisa membuka pemilih file: $e');
      return null;
    }
  }

  String _photoTitle() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Foto ${two(n.day)}-${two(n.month)}-${n.year} ${two(n.hour)}.${two(n.minute)}';
  }

  Future<String?> _askTitle(String initial) {
    final c = TextEditingController(text: initial);
    return showSmoothDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Judul dokumen'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Mis. Putusan PKPU No. 12'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  /// Pilihan sumber: file, foto dari galeri, atau kamera.
  void _addSheet() {
    if (_busy) return;
    Widget tile(IconData icon, String title, String sub, String kind) => ListTile(
          minVerticalPadding: 12,
          leading: IconBadge(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(sub),
          onTap: () {
            Navigator.pop(context);
            _upload(kind: kind);
          },
        );
    showSmoothSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            tile(Icons.upload_file_outlined, 'Upload dokumen', 'PDF, Word, Excel, atau gambar (maks 20 MB)', 'file'),
            tile(Icons.photo_library_outlined, 'Foto dari galeri', 'Pilih foto yang sudah ada di HP', 'gallery'),
            tile(Icons.photo_camera_outlined, 'Ambil foto', 'Foto dokumen langsung dengan kamera', 'camera'),
          ]),
        ),
      ),
    );
  }

  String _newPath(PlatformFile f) {
    final uid = _db.auth.currentUser!.id;
    final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
  }

  Future<void> _upload({String kind = 'file'}) async {
    if (_busy) return;
    if (Access.instance.memberId == null) {
      _snack('Akun Anda belum terhubung ke data anggota, jadi belum bisa mengunggah.');
      return;
    }
    final f = await _pick(kind: kind);
    if (f == null || !mounted) return;
    final title = await _askTitle(kind == 'file' ? f.name : _photoTitle());
    if (title == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final path = _newPath(f);
      await uploadPicked(_db, 'documents', path, f);
      final ins = await _db.from('documents').insert({
        'title': title.isEmpty ? f.name : title,
        'bucket': 'documents',
        'file_path': path,
        'mime_type': f.extension,
        'size_bytes': f.size,
        'uploaded_by': Access.instance.memberId,
      }).select('id').single();
      _indexOne('${ins['id']}');
      await _db.rpc('log_event', params: {'p_action': 'upload', 'p_module': 'documents', 'p_record': path});
      _snack('Dokumen berhasil diunggah.');
      await _load();
    } on StorageException catch (e) {
      _snack('Upload ditolak: ${e.message}. Jalankan sql/19_documents_upload.sql di Supabase.');
    } on PostgrestException catch (e) {
      _snack('Data dokumen ditolak: ${e.message}. Jalankan sql/19_documents_upload.sql di Supabase.');
    } catch (e) {
      _snack('Upload gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Upload versi baru: file lama otomatis disimpan sebagai riwayat oleh trigger database.
  Future<void> _uploadVersion(Map<String, dynamic> d) async {
    final f = await _pick();
    if (f == null) return;
    setState(() => _busy = true);
    String? path;
    final bucket = (d['bucket'] ?? 'documents') as String;
    try {
      path = _newPath(f);
      await uploadPicked(_db, bucket, path, f);
      final updated = await _db
          .from('documents')
          .update({'file_path': path, 'mime_type': f.extension, 'size_bytes': f.size})
          .eq('id', d['id'])
          .select('id');
      if ((updated as List).isEmpty) throw StateError('no rows updated');
      await _db.rpc('log_event',
          params: {'p_action': 'new_version', 'p_module': 'documents', 'p_record': '${d['id']}'});
      _indexOne('${d['id']}');
      _snack('Versi baru berhasil diunggah.');
      await _load();
    } catch (_) {
      if (path != null) {
        try {
          await _db.storage.from(bucket).remove([path]);
        } catch (_) {}
      }
      _snack('Gagal mengunggah versi baru. Pastikan skrip sql/07_document_versions.sql sudah dijalankan.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPath(String bucket, String path, String logId) async {
    try {
      final url = await _db.storage.from(bucket).createSignedUrl(path, 120);
      await _db.rpc('log_event', params: {'p_action': 'download', 'p_module': 'documents', 'p_record': logId});
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Tidak dapat membuka dokumen.');
    }
  }

  Future<void> _summarize(Map<String, dynamic> d) async {
    showSmoothDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    String? summary;
    String? err;
    try {
      final res = await _db.functions.invoke('ai-summarize-document', body: {'document_id': d['id']});
      final data = res.data;
      if (data is Map && data['summary'] is String && (data['summary'] as String).isNotEmpty) {
        summary = data['summary'] as String;
      } else {
        err = 'AI tidak dapat meringkas dokumen ini.';
      }
    } on FunctionException catch (e) {
      final det = e.details;
      err = (det is Map && det['message'] is String)
          ? det['message'] as String
          : 'Layanan AI belum tersedia atau terjadi gangguan. Coba lagi nanti.';
    } catch (_) {
      err = 'Layanan AI belum tersedia atau terjadi gangguan. Coba lagi nanti.';
    }
    if (!mounted) return;
    Navigator.of(context).pop(); // tutup indikator
    await showSmoothDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ringkasan AI'),
        content: SingleChildScrollView(child: SelectableText(summary ?? err ?? '')),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus dokumen?'),
        content: const Text('Seluruh versi dokumen ini akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final bucket = (d['bucket'] ?? 'documents') as String;
      final paths = <String>[d['file_path'] as String];
      try {
        final vs = await _db.from('document_versions').select('file_path,bucket').eq('document_id', d['id']);
        for (final v in vs) {
          if ((v['bucket'] ?? 'documents') == bucket) paths.add(v['file_path'] as String);
        }
      } catch (_) {
        // tabel versi belum ada: abaikan
      }
      await _db.storage.from(bucket).remove(paths);
      await _db.from('documents').delete().eq('id', d['id']);
      await _load();
    } catch (_) {
      _snack('Gagal menghapus dokumen.');
    }
  }

  void _details(Map<String, dynamic> d, bool canWrite) {
    showSmoothSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => _DocSheet(
        doc: d,
        canWrite: canWrite,
        onOpen: (b, p, id) {
          Navigator.pop(c);
          _openPath(b, p, id);
        },
        onSummarize: () {
          Navigator.pop(c);
          _summarize(d);
        },
        onNewVersion: () {
          Navigator.pop(c);
          _uploadVersion(d);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = Access.instance.can('manage_document');
    if (!Access.instance.can('view_document')) return const AccessDenied();
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumen'), actions: [
        if (canWrite)
          IconButton(
            onPressed: _busy ? null : _reindexAll,
            icon: const Icon(Icons.manage_search),
            tooltip: 'Indeks isi PDF (agar bisa dicari)',
          ),
      ]),
      // Dibungkus NavClearance: tanpa ini tombol tertimpa bar navigasi mengambang dan tidak terlihat.
      floatingActionButton: NavClearance(
        child: FloatingActionButton.extended(
          onPressed: _busy ? null : _addSheet,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file),
          label: Text(_busy ? 'Mengunggah...' : 'Upload'),
        ),
      ),
      body: PageGlow(accent: AppColors.sky, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: ScreenHero(
            title: 'Dokumen',
            subtitle: 'Arsip, versi, dan tanda tangan digital',
            icon: Icons.folder_outlined,
            accent: AppColors.sky,
            chips: [(Icons.description_outlined, '${_rows.length} dokumen')],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Cari judul atau isi dokumen', prefixIcon: Icon(Icons.search), isDense: true),
            onSubmitted: (v) {
              _q = v;
              _load();
            },
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorState(message: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const EmptyState(message: 'Belum ada dokumen.\nUnggah file atau foto dokumen pertama Anda.'),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                                  onPressed: _busy ? null : () => _upload(kind: 'file'),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Dokumen'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                                  onPressed: _busy ? null : _addSheet,
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Foto'),
                                ),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 96),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final d = _rows[i];
                            final sc = Theme.of(context).colorScheme;
                            return AppCard(
                              radius: 20,
                              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                              onTap: () => _details(d, canWrite),
                              child: Row(children: [
                                const IconBadge(Icons.description_outlined),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${d['title'] ?? d['file_path']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text('v${d['version'] ?? 1} • ${fmtValue(d['created_at'])}',
                                        style: TextStyle(fontSize: 13, color: sc.onSurfaceVariant)),
                                  ]),
                                ),
                                if (canWrite)
                                  IconButton(
                                      tooltip: 'Hapus',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(d))
                                else
                                  Icon(Icons.chevron_right_rounded, color: sc.onSurfaceVariant),
                              ]),
                            );
                          },
                        ),
        ),
      ])),
    );
  }
}

class _DocSheet extends StatefulWidget {
  const _DocSheet({
    required this.doc,
    required this.canWrite,
    required this.onOpen,
    required this.onSummarize,
    required this.onNewVersion,
  });
  final Map<String, dynamic> doc;
  final bool canWrite;
  final void Function(String bucket, String path, String logId) onOpen;
  final VoidCallback onSummarize, onNewVersion;
  @override
  State<_DocSheet> createState() => _DocSheetState();
}

class _DocSheetState extends State<_DocSheet> {
  List<Map<String, dynamic>> _versions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    try {
      final rows = await SupabaseService.client
          .from('document_versions')
          .select()
          .eq('document_id', widget.doc['id'])
          .order('version', ascending: false);
      _versions = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      _versions = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _size(dynamic b) {
    final n = (b is num) ? b.toDouble() : double.tryParse('$b');
    if (n == null) return '';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final bucket = (d['bucket'] ?? 'documents') as String;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), shrinkWrap: true, children: [
          Text('${d['title'] ?? d['file_path']}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Versi saat ini: v${d['version'] ?? 1} • ${_size(d['size_bytes'])}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => widget.onOpen(bucket, d['file_path'] as String, '${d['id']}'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Buka'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onSummarize,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Ringkas dengan AI'),
            ),
            if (widget.canWrite)
              OutlinedButton.icon(
                onPressed: widget.onNewVersion,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload versi baru'),
              ),
          ]),
          const SizedBox(height: 4),
          const Text('Ringkasan AI mendukung PDF, JPG, PNG (maks 10 MB).', style: TextStyle(fontSize: 11)),
          const Divider(height: 28),
          DocumentSignatures(docId: '${d['id']}'),
          const Divider(height: 28),
          Text('Riwayat versi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_versions.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Belum ada versi sebelumnya.'))
          else
            for (final v in _versions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text('Versi ${v['version']}'),
                subtitle: Text('${fmtValue(v['created_at'])} • ${_size(v['size_bytes'])}'),
                onTap: () => widget.onOpen(
                    (v['bucket'] ?? bucket) as String, v['file_path'] as String, '${d['id']}'),
              ),
        ]),
      ),
    );
  }
}
