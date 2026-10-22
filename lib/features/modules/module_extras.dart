import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/icon_badge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/repositories/data_repository.dart';
import '../../core/utils/upload_helper.dart';

SupabaseClient get _db => SupabaseService.client;

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String _when(dynamic v) {
  final d = DateTime.tryParse('$v')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Bagian tambahan pada halaman detail modul (hanya untuk data yang sudah tersimpan).
List<Widget> moduleExtras(String moduleId, String rowId, Map<String, dynamic> row) {
  final me = Access.instance.memberId;
  switch (moduleId) {
    case 'forum':
      return [ForumSection(postId: rowId)];
    case 'events':
      return [
        EventRsvpSection(eventId: rowId),
        Attachments(
            entityType: 'event',
            entityId: rowId,
            bucket: 'event-attachments',
            canUpload: Access.instance.can('manage_event')),
      ];
    case 'notes':
      final owner = me != null && row['member_id'] == me;
      return [
        if (owner) NoteShareSection(noteId: rowId),
        Attachments(
            entityType: 'note',
            entityId: rowId,
            bucket: 'note-attachments',
            canUpload: owner),
      ];
    default:
      return const [];
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconBadge(icon, size: 34),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

// ---------------------------------------------------------------------
// Forum: like + komentar
// ---------------------------------------------------------------------
class ForumSection extends StatefulWidget {
  const ForumSection({super.key, required this.postId});
  final String postId;
  @override
  State<ForumSection> createState() => _ForumSectionState();
}

class _ForumSectionState extends State<ForumSection> {
  final _ctl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int _likes = 0;
  bool _liked = false, _loading = true, _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = Access.instance.memberId;
      final likes = await _db.from('forum_likes').select('member_id').eq('post_id', widget.postId);
      final comments = await _db
          .from('forum_comments')
          .select('id,body,created_at,author_id,members(full_name)')
          .eq('post_id', widget.postId)
          .order('created_at');
      _likes = (likes as List).length;
      _liked = likes.any((e) => e['member_id'] == me);
      _comments = List<Map<String, dynamic>>.from(comments);
    } catch (_) {
      if (mounted) _snack(context, 'Gagal memuat komentar.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleLike() async {
    final me = Access.instance.memberId;
    if (me == null) return;
    try {
      if (_liked) {
        await _db.from('forum_likes').delete().eq('post_id', widget.postId).eq('member_id', me);
      } else {
        await _db.from('forum_likes').insert({'post_id': widget.postId, 'member_id': me});
      }
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Gagal memperbarui suka.');
    }
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _db.from('forum_comments').insert({
        'post_id': widget.postId,
        'author_id': Access.instance.memberId,
        'body': t,
      });
      _ctl.clear();
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Komentar gagal dikirim.');
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    try {
      await _db.from('forum_comments').delete().eq('id', c['id']);
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Gagal menghapus komentar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Access.instance.memberId;
    final mod = Access.instance.can('moderate_forum');
    return _Box(
      title: 'Diskusi',
      icon: Icons.forum_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
          onPressed: _loading ? null : _toggleLike,
          icon: Icon(_liked ? Icons.thumb_up : Icons.thumb_up_outlined),
          label: Text('$_likes suka'),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada komentar.'))
        else
          for (final c in _comments)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${c['body']}'),
              subtitle: Text('${(c['members'] as Map?)?['full_name'] ?? 'Anggota'} • ${_when(c['created_at'])}'),
              trailing: (c['author_id'] == me || mod)
                  ? IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(c))
                  : null,
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Tulis komentar', isDense: true),
            ),
          ),
          IconButton.filled(
              onPressed: _sending ? null : _send, icon: const Icon(Icons.send), tooltip: 'Kirim'),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
// Event: RSVP
// ---------------------------------------------------------------------
class EventRsvpSection extends StatefulWidget {
  const EventRsvpSection({super.key, required this.eventId});
  final String eventId;
  @override
  State<EventRsvpSection> createState() => _EventRsvpSectionState();
}

class _EventRsvpSectionState extends State<EventRsvpSection> {
  Map<String, int> _counts = {'Hadir': 0, 'Mungkin': 0, 'Tidak': 0};
  String? _mine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = Access.instance.memberId;
      final rows = await _db
          .from('event_rsvps')
          .select('member_id,status')
          .eq('event_id', widget.eventId);
      final c = {'Hadir': 0, 'Mungkin': 0, 'Tidak': 0};
      String? mine;
      for (final r in rows as List) {
        final s = '${r['status']}';
        c[s] = (c[s] ?? 0) + 1;
        if (r['member_id'] == me) mine = s;
      }
      _counts = c;
      _mine = mine;
    } catch (_) {
      if (mounted) _snack(context, 'Gagal memuat RSVP. Pastikan skrip perkapi_features.sql sudah dijalankan.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String status) async {
    try {
      await _db.from('event_rsvps').upsert({
        'event_id': widget.eventId,
        'member_id': Access.instance.memberId,
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'event_id,member_id');
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Gagal menyimpan RSVP.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Box(
      title: 'Konfirmasi Kehadiran (RSVP)',
      icon: Icons.how_to_reg_outlined,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<String>(
                emptySelectionAllowed: true,
                segments: const [
                  ButtonSegment(value: 'Hadir', label: Text('Hadir')),
                  ButtonSegment(value: 'Mungkin', label: Text('Mungkin')),
                  ButtonSegment(value: 'Tidak', label: Text('Tidak')),
                ],
                selected: _mine == null ? <String>{} : {_mine!},
                onSelectionChanged: (s) {
                  if (s.isNotEmpty) _set(s.first);
                },
              ),
              const SizedBox(height: 8),
              Text('Hadir ${_counts['Hadir']} • Mungkin ${_counts['Mungkin']} • Tidak ${_counts['Tidak']}'),
            ]),
    );
  }
}

// ---------------------------------------------------------------------
// Catatan: berbagi dengan anggota lain
// ---------------------------------------------------------------------
class NoteShareSection extends StatefulWidget {
  const NoteShareSection({super.key, required this.noteId});
  final String noteId;
  @override
  State<NoteShareSection> createState() => _NoteShareSectionState();
}

class _NoteShareSectionState extends State<NoteShareSection> {
  List<Map<String, dynamic>> _shares = [];
  List<Map<String, dynamic>> _members = [];
  String? _pick;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('personal_note_shares')
          .select('id,shared_with,members(full_name)')
          .eq('note_id', widget.noteId);
      _shares = List<Map<String, dynamic>>.from(rows);
      _members = await DataRepository.lookup('members', 'full_name');
    } catch (_) {
      if (mounted) _snack(context, 'Gagal memuat daftar berbagi.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _share() async {
    if (_pick == null) return;
    try {
      await _db.from('personal_note_shares').insert({
        'note_id': widget.noteId,
        'shared_with': _pick,
      });
      _pick = null;
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) {
        _snack(context, e.code == '23505' ? 'Sudah dibagikan ke anggota ini.' : 'Gagal membagikan catatan.');
      }
    } catch (_) {
      if (mounted) _snack(context, 'Gagal membagikan catatan.');
    }
  }

  Future<void> _unshare(Map<String, dynamic> s) async {
    try {
      await _db.from('personal_note_shares').delete().eq('id', s['id']);
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Gagal mencabut akses.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Access.instance.memberId;
    final sharedIds = _shares.map((e) => e['shared_with']).toSet();
    final options = _members.where((m) => m['id'] != me && !sharedIds.contains(m['id'])).toList();
    return _Box(
      title: 'Bagikan catatan',
      icon: Icons.share_outlined,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_shares.isEmpty) const Text('Belum dibagikan kepada siapa pun.'),
              for (final s in _shares)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text('${(s['members'] as Map?)?['full_name'] ?? 'Anggota'}'),
                  trailing: IconButton(
                      tooltip: 'Cabut akses',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => _unshare(s)),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: options.any((o) => o['id'] == _pick) ? _pick : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pilih anggota', isDense: true),
                    items: [
                      for (final o in options)
                        DropdownMenuItem(
                          value: o['id'] as String,
                          child: Text('${o['full_name'] ?? '-'}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _pick = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _pick == null ? null : _share, child: const Text('Bagikan')),
              ]),
            ]),
    );
  }
}

// ---------------------------------------------------------------------
// Lampiran (catatan, event) - bucket privat + signed URL
// ---------------------------------------------------------------------
class Attachments extends StatefulWidget {
  const Attachments({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.bucket,
    required this.canUpload,
  });
  final String entityType, entityId, bucket;
  final bool canUpload;
  @override
  State<Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<Attachments> {
  static const _allowed = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'];
  static const _maxBytes = 10 * 1024 * 1024;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _db
          .from('attachments')
          .select()
          .eq('entity_type', widget.entityType)
          .eq('entity_id', widget.entityId)
          .order('created_at');
      _rows = List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      if (mounted) _snack(context, 'Gagal memuat lampiran. Pastikan skrip perkapi_features.sql sudah dijalankan.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowed,
      withData: pickWithData,
    );
    final f = res?.files.single;
    if (f == null || !hasSource(f)) return;
    if (f.size > _maxBytes) {
      if (mounted) _snack(context, 'Ukuran file maksimal 10 MB.');
      return;
    }
    setState(() => _busy = true);
    String? path;
    try {
      final uid = _db.auth.currentUser!.id;
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
      await uploadPicked(_db, widget.bucket, path, f);
      await _db.from('attachments').insert({
        'entity_type': widget.entityType,
        'entity_id': widget.entityId,
        'bucket': widget.bucket,
        'file_path': path,
        'file_name': f.name,
        'mime_type': f.extension,
        'size_bytes': f.size,
        'uploaded_by': Access.instance.memberId,
      });
      await _load();
    } on StorageException {
      if (mounted) _snack(context, 'Upload ditolak. Anda mungkin tidak memiliki izin.');
    } catch (_) {
      if (path != null) {
        try {
          await _db.storage.from(widget.bucket).remove([path]);
        } catch (_) {}
      }
      if (mounted) _snack(context, 'Upload gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Map<String, dynamic> a) async {
    try {
      final url = await _db.storage.from(widget.bucket).createSignedUrl(a['file_path'] as String, 120);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack(context, 'Tidak dapat membuka lampiran.');
    }
  }

  Future<void> _delete(Map<String, dynamic> a) async {
    try {
      await _db.storage.from(widget.bucket).remove([a['file_path'] as String]);
      await _db.from('attachments').delete().eq('id', a['id']);
      await _load();
    } catch (_) {
      if (mounted) _snack(context, 'Gagal menghapus lampiran.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Access.instance.memberId;
    return _Box(
      title: 'Lampiran',
      icon: Icons.attach_file,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_rows.isEmpty)
          const Text('Belum ada lampiran.')
        else
          for (final a in _rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text('${a['file_name'] ?? a['file_path']}', overflow: TextOverflow.ellipsis),
              subtitle: Text(_when(a['created_at'])),
              onTap: () => _open(a),
              trailing: a['uploaded_by'] == me
                  ? IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _delete(a))
                  : null,
            ),
        if (widget.canUpload) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _upload,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: const Text('Tambah lampiran'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('PDF, Word, Excel, JPG, PNG • maks 10 MB', style: TextStyle(fontSize: 11)),
          ),
        ],
      ]),
    );
  }
}
