import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/online_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/motion.dart' show reduceMotion, SkeletonList;
import '../../core/widgets/page_glow.dart';
import 'call_service.dart';
import 'chat_list_page.dart';
import 'chat_media.dart';
import 'chat_profile_page.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/constants/app_tokens.dart';

const _cols = 'id,sender_id,body,created_at,kind,attachment_path,attachment_name,attachment_size,attachment_mime,duration_ms,reply_to,edited_at,deleted_at';

/// Percakapan satu thread, seperti WhatsApp:
/// teks, foto, dokumen, pesan suara; balas (geser kanan / tekan lama), edit & hapus untuk semua,
/// centang terkirim/dibaca, "sedang mengetik…", status online, serta telepon & video call (chat pribadi).
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.threadId});
  final String threadId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _db = SupabaseService.client;
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _rec = VoiceRecorder();

  List<Map<String, dynamic>> _msgs = []; // terbaru di indeks 0
  final Map<String, String> _names = {};
  final Map<String, DateTime> _reads = {}; // member_id -> terakhir dibaca
  final Map<String, DateTime> _delivered = {}; // member_id -> terakhir pesan sampai di HP-nya
  final Map<String, DateTime> _typing = {}; // member_id -> kapan terakhir mengetik
  String _title = 'Chat';
  bool _group = false, _loading = true, _sending = false;
  String? _error, _uploading;
  RealtimeChannel? _ch;
  Timer? _typingTick;
  DateTime _lastTypingSent = DateTime(2000);

  Map<String, dynamic>? _replyTo, _editing;
  bool _recording = false;
  DateTime? _recStart;
  Timer? _recTick;

  String? get _me => Access.instance.memberId;
  String? get _peerId => _group ? null : _names.keys.firstWhere((k) => k != _me, orElse: () => '');

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInput);
    OnlineService.instance.online.addListener(_rebuild);
    _init();
  }

  @override
  void dispose() {
    OnlineService.instance.online.removeListener(_rebuild);
    final ch = _ch;
    if (ch != null) _db.removeChannel(ch);
    _typingTick?.cancel();
    _recTick?.cancel();
    if (_recording) _rec.cancel();
    _rec.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  String? _peerAvatar;

  Future<void> _loadPeerAvatar() async {
    final peer = _peerId;
    if (peer == null || peer.isEmpty) return;
    try {
      final r = List<Map<String, dynamic>>.from(await _db.rpc('chat_member_profile', params: {'p_member': peer}) as List);
      if (r.isNotEmpty && mounted) setState(() => _peerAvatar = r.first['avatar_path'] as String?);
    } catch (_) {}
  }

  void _openProfile() {
    final peer = _peerId;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatProfilePage(
        threadId: widget.threadId,
        memberId: _group ? null : peer,
        isGroup: _group,
        title: _title,
      ),
    ));
  }

  // ---------------------------------------------------------------- data
  Future<void> _init() async {
    try {
      final ov = List<Map<String, dynamic>>.from(await _db.rpc('chat_threads_overview') as List);
      final t = ov.firstWhere((e) => '${e['thread_id']}' == widget.threadId, orElse: () => {});
      _title = '${t['title'] ?? 'Chat'}';
      _group = t['kind'] == 'group';
      final mem = List<Map<String, dynamic>>.from(await _db.rpc('chat_thread_members', params: {'p_thread': widget.threadId}) as List);
      for (final m in mem) {
        _names['${m['member_id']}'] = '${m['name']}';
      }
      final rows = await _db.from('chat_messages').select(_cols).eq('thread_id', widget.threadId).order('created_at', ascending: false).limit(200);
      _msgs = List<Map<String, dynamic>>.from(rows as List);
      await _loadReads();
      _subscribe();
      _markRead();
      _loadPeerAvatar();
      if (mounted) setState(() { _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal memuat percakapan.'; });
    }
  }

  Future<void> _loadReads() async {
    try {
      final r = List<Map<String, dynamic>>.from(await _db.rpc('chat_read_state', params: {'p_thread': widget.threadId}) as List);
      for (final x in r) {
        final d = DateTime.tryParse('${x['last_read_at']}');
        if (d != null) _reads['${x['member_id']}'] = d;
        final dv = DateTime.tryParse('${x['last_delivered_at']}');
        if (dv != null) _delivered['${x['member_id']}'] = dv;
      }
    } catch (_) {
      // SQL 41 belum dijalankan: centang biru tidak tampil, chat tetap jalan
    }
  }

  void _subscribe() {
    final filter = PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'thread_id', value: widget.threadId);
    _ch = _db
        .channel('chat-${widget.threadId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'chat_messages', filter: filter, callback: (p) => _upsert(Map<String, dynamic>.from(p.newRecord)))
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'chat_messages', filter: filter, callback: (p) => _upsert(Map<String, dynamic>.from(p.newRecord)))
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_participants',
          filter: filter,
          callback: (p) {
            final who = '${p.newRecord['member_id']}';
            final d = DateTime.tryParse('${p.newRecord['last_read_at']}');
            final dv = DateTime.tryParse('${p.newRecord['last_delivered_at']}');
            if (!mounted) return;
            setState(() {
              if (d != null) _reads[who] = d;
              if (dv != null) _delivered[who] = dv;
            });
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final who = '${payload['member']}';
            if (who == _me || !mounted) return;
            setState(() {
              if (payload['on'] == true) {
                _typing[who] = DateTime.now();
              } else {
                _typing.remove(who);
              }
            });
            _typingTick ??= Timer.periodic(const Duration(seconds: 1), (_) => _expireTyping());
          },
        )
        .subscribe();
  }

  void _expireTyping() {
    final now = DateTime.now();
    final before = _typing.length;
    _typing.removeWhere((_, t) => now.difference(t) > const Duration(seconds: 5));
    if (_typing.isEmpty) {
      _typingTick?.cancel();
      _typingTick = null;
    }
    if (before != _typing.length && mounted) setState(() {});
  }

  void _upsert(Map<String, dynamic> m) {
    if (!mounted) return;
    final i = _msgs.indexWhere((e) => e['id'] == m['id']);
    setState(() {
      if (i >= 0) {
        _msgs[i] = {..._msgs[i], ...m};
      } else {
        _msgs.insert(0, m);
        _typing.remove('${m['sender_id']}');
      }
    });
    if (i < 0 && m['sender_id'] != _me) _markRead();
  }

  void _markRead() {
    _db.rpc('chat_mark_read', params: {'p_thread': widget.threadId}).catchError((_) {});
  }

  void _onInput() {
    if (mounted) setState(() {}); // ganti tombol mikrofon <-> kirim
    final ch = _ch;
    if (ch == null || _input.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) return;
    _lastTypingSent = now;
    ch.sendBroadcastMessage(event: 'typing', payload: {'member': _me, 'on': true});
  }

  void _typingOff() {
    _lastTypingSent = DateTime(2000);
    _ch?.sendBroadcastMessage(event: 'typing', payload: {'member': _me, 'on': false});
  }

  // ---------------------------------------------------------------- kirim
  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _me == null) return;
    final editing = _editing;
    if (editing != null) {
      await _saveEdit(editing, text);
      return;
    }
    setState(() => _sending = true);
    try {
      final r = await _db
          .from('chat_messages')
          .insert({
            'thread_id': widget.threadId,
            'sender_id': _me,
            'body': text,
            if (_replyTo != null) 'reply_to': _replyTo!['id'],
          })
          .select(_cols)
          .single();
      _input.clear();
      _typingOff();
      setState(() => _replyTo = null);
      _upsert(Map<String, dynamic>.from(r));
      _markRead();
    } catch (_) {
      _snack('Pesan gagal terkirim.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment({required Uint8List bytes, required String name, required String kind, String? mime, int? durationMs, String caption = ''}) async {
    final me = _me;
    if (me == null) return;
    setState(() => _uploading = kind == 'audio' ? 'Mengirim pesan suara…' : 'Mengunggah $name…');
    try {
      final path = await ChatFiles.upload(threadId: widget.threadId, memberId: me, bytes: bytes, name: name, mime: mime);
      final r = await _db
          .from('chat_messages')
          .insert({
            'thread_id': widget.threadId,
            'sender_id': me,
            'body': caption,
            'kind': kind,
            'attachment_path': path,
            'attachment_name': name,
            'attachment_size': bytes.length,
            'attachment_mime': mime ?? ChatFiles.mimeFor(name),
            if (durationMs != null) 'duration_ms': durationMs,
            if (_replyTo != null) 'reply_to': _replyTo!['id'],
          })
          .select(_cols)
          .single();
      if (mounted) setState(() => _replyTo = null);
      _upsert(Map<String, dynamic>.from(r));
    } on ChatUploadException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Lampiran gagal terkirim. Pastikan pembaruan database chat (SQL 41) sudah dijalankan.');
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final x = await _picker.pickImage(source: src, maxWidth: 1920, maxHeight: 1920, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final caption = _input.text.trim();
      _input.clear();
      await _sendAttachment(bytes: bytes, name: x.name.isEmpty ? 'foto.jpg' : x.name, kind: 'image', mime: x.mimeType ?? 'image/jpeg', caption: caption);
    } catch (_) {
      _snack('Tidak dapat membuka ${src == ImageSource.camera ? 'kamera' : 'galeri'}.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      final f = r?.files.single;
      if (f == null || f.bytes == null) return;
      final isImg = RegExp(r'\.(jpe?g|png|webp|heic)$', caseSensitive: false).hasMatch(f.name);
      await _sendAttachment(bytes: f.bytes!, name: f.name, kind: isImg ? 'image' : 'file');
    } catch (_) {
      _snack('Tidak dapat memilih berkas.');
    }
  }

  void _attachSheet() {
    showSmoothSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _AttachOpt(icon: CupertinoIcons.camera_fill, label: 'Kamera', color: AppColors.red, onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            }),
            _AttachOpt(icon: CupertinoIcons.photo_on_rectangle, label: 'Galeri', color: AppColors.violet, onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            }),
            _AttachOpt(icon: CupertinoIcons.doc_text_fill, label: 'Dokumen', color: AppColors.navyAction, onTap: () {
              Navigator.pop(ctx);
              _pickFile();
            }),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pesan suara
  Future<void> _recStartTap() async {
    HapticFeedback.mediumImpact();
    final ok = await _rec.start();
    if (!ok) {
      _snack('Izinkan akses mikrofon untuk merekam pesan suara.');
      return;
    }
    setState(() {
      _recording = true;
      _recStart = DateTime.now();
    });
    _recTick = Timer.periodic(const Duration(milliseconds: 250), (_) => _rebuild());
  }

  Future<void> _recFinish({required bool send}) async {
    _recTick?.cancel();
    setState(() => _recording = false);
    if (!send) {
      await _rec.cancel();
      return;
    }
    final r = await _rec.stop();
    if (r == null) {
      _snack('Tahan sedikit lebih lama untuk merekam.');
      return;
    }
    await _sendAttachment(bytes: r.$1, name: 'pesan-suara.m4a', kind: 'audio', mime: 'audio/mp4', durationMs: r.$2);
  }

  // ---------------------------------------------------------------- aksi pesan
  void _actions(Map<String, dynamic> m) {
    final mine = m['sender_id'] == _me;
    final deleted = m['deleted_at'] != null;
    final kind = '${m['kind'] ?? 'text'}';
    final created = DateTime.tryParse('${m['created_at']}');
    final canEdit = mine && !deleted && (kind == 'text' || kind == 'image' || kind == 'file') && created != null && DateTime.now().difference(created.toLocal()) < const Duration(minutes: 15);
    HapticFeedback.selectionClick();
    showSmoothSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!deleted && kind != 'call')
            ListTile(leading: const Icon(CupertinoIcons.arrowshape_turn_up_left), title: const Text('Balas'), onTap: () {
              Navigator.pop(ctx);
              _startReply(m);
            }),
          if (!deleted && '${m['body'] ?? ''}'.isNotEmpty)
            ListTile(leading: const Icon(CupertinoIcons.doc_on_doc), title: const Text('Salin teks'), onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: '${m['body']}'));
              _snack('Teks disalin.');
            }),
          if (canEdit)
            ListTile(leading: const Icon(CupertinoIcons.pencil), title: Text(kind == 'text' ? 'Edit' : 'Edit keterangan'), onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _editing = m;
                _replyTo = null;
                _input.text = '${m['body'] ?? ''}';
              });
              _focus.requestFocus();
            }),
          if (mine && !deleted && kind != 'call')
            ListTile(
              leading: const Icon(CupertinoIcons.trash, color: AppColors.red),
              title: const Text('Hapus untuk semua', style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(m);
              },
            ),
        ]),
      ),
    );
  }

  void _startReply(Map<String, dynamic> m) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyTo = m;
      _editing = null;
    });
    _focus.requestFocus();
  }

  Future<void> _saveEdit(Map<String, dynamic> m, String text) async {
    setState(() => _sending = true);
    try {
      final r = await _db.from('chat_messages').update({'body': text}).eq('id', m['id']).select(_cols).single();
      _upsert(Map<String, dynamic>.from(r));
      _input.clear();
      setState(() => _editing = null);
    } catch (e) {
      _snack(e is PostgrestException && e.message.contains('15 menit') ? 'Pesan hanya bisa diedit dalam 15 menit.' : 'Gagal mengedit pesan.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus pesan untuk semua?'),
        content: const Text('Pesan ini akan diganti tulisan "Pesan ini telah dihapus" di semua peserta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final path = m['attachment_path'] as String?;
    try {
      final r = await _db.from('chat_messages').update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', m['id']).select(_cols).single();
      _upsert(Map<String, dynamic>.from(r));
      unawaited(ChatFiles.remove(path));
    } catch (_) {
      _snack('Gagal menghapus pesan.');
    }
  }

  void _snack(String t) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  // ---------------------------------------------------------------- tampilan
  String get _subtitle {
    final typers = _typing.keys.where((k) => k != _me).toList();
    if (typers.isNotEmpty) {
      if (!_group) return 'sedang mengetik…';
      final n = typers.map((k) => (_names[k] ?? 'Anggota').split(' ').first).toList();
      return n.length == 1 ? '${n.first} mengetik…' : '${n.length} orang mengetik…';
    }
    if (_group) return '${_names.length} anggota';
    return OnlineService.instance.isOnline(_peerId) ? 'online' : '';
  }

  /// Dibaca semua peserta lain sejak pesan dikirim?
  bool _readByAll(Map<String, dynamic> m) => _allSince(m, _reads);

  /// Sudah sampai di HP semua peserta lain (atau sudah dibaca)?
  bool _deliveredToAll(Map<String, dynamic> m) => _allSince(m, _delivered) || _readByAll(m);

  bool _allSince(Map<String, dynamic> m, Map<String, DateTime> marks) {
    final at = DateTime.tryParse('${m['created_at']}');
    if (at == null) return false;
    final others = _names.keys.where((k) => k != _me).toList();
    if (others.isEmpty) return false;
    return others.every((k) {
      final r = marks[k];
      return r != null && !r.isBefore(at);
    });
  }

  /// Centang ala WhatsApp: ✓ terkirim, ✓✓ abu-abu sampai, ✓✓ biru dibaca.
  Widget _ticks(Map<String, dynamic> m, Color sub) {
    final read = _readByAll(m);
    final two = read || _deliveredToAll(m);
    final c = read ? const Color(0xFF53BDEB) : sub;
    if (!two) return Icon(CupertinoIcons.checkmark_alt, size: 15, color: c);
    return SizedBox(
      width: 21,
      height: 15,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 0, top: 0, child: Icon(CupertinoIcons.checkmark_alt, size: 15, color: c)),
        Positioned(left: 6, top: 0, child: Icon(CupertinoIcons.checkmark_alt, size: 15, color: c)),
      ]),
    );
  }

  /// Pesan saya paling baru (indeks di _msgs, 0 = paling baru), selain panggilan & yang dihapus.
  int get _lastMineIndex => _msgs.indexWhere((e) => e['sender_id'] == _me && '${e['kind']}' != 'call' && e['deleted_at'] == null);

  /// Keterangan "Dilihat" di bawah pesan terakhir saya bila sudah dibaca.
  Widget _seenLabel(Map<String, dynamic> m, ColorScheme scheme) {
    if (!_readByAll(m)) return const SizedBox.shrink();
    String label;
    if (_group) {
      label = 'Dilihat semua';
    } else {
      final at = _reads[_peerId]?.toLocal();
      final now = DateTime.now();
      final hh = at == null ? '' : '${at.hour.toString().padLeft(2, '0')}.${at.minute.toString().padLeft(2, '0')}';
      final today = at != null && at.year == now.year && at.month == now.month && at.day == now.day;
      label = at == null ? 'Dilihat' : (today ? 'Dilihat $hh' : 'Dilihat ${at.day}/${at.month} $hh');
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 14, top: 2, bottom: 4),
        child: Text(label, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      ),
    );
  }

  Map<String, dynamic>? _find(String? id) {
    if (id == null) return null;
    for (final m in _msgs) {
      if (m['id'] == id) return m;
    }
    return null;
  }

  static String _preview(Map<String, dynamic>? m) {
    if (m == null) return 'Pesan';
    if (m['deleted_at'] != null) return 'Pesan ini telah dihapus';
    final body = '${m['body'] ?? ''}'.trim();
    switch ('${m['kind'] ?? 'text'}') {
      case 'image':
        return body.isEmpty ? 'Foto' : 'Foto · $body';
      case 'file':
        return 'Dokumen · ${m['attachment_name'] ?? 'Berkas'}';
      case 'audio':
        return 'Pesan suara';
      default:
        return body;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = _subtitle;
    final peer = _peerId;
    return Scaffold(
      appBar: GlassAppBar(
        titleSpacing: 0,
        // ketuk nama/foto di atas untuk membuka info kontak / info grup (seperti WhatsApp)
        title: InkWell(
          onTap: _loading ? null : _openProfile,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              _group
                  ? const CircleAvatar(radius: 18, backgroundColor: AppColors.navyAction, child: Icon(CupertinoIcons.person_3_fill, size: 20, color: Colors.white))
                  : MemberAvatar(name: _title, path: _peerAvatar, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion(context) ? 0 : 180),
            child: sub.isEmpty
                ? const SizedBox.shrink()
                : Text(sub,
                    key: ValueKey(sub),
                    style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: sub == 'online' || sub.contains('ketik') ? AppColors.emerald : scheme.onSurfaceVariant)),
          ),
                ]),
              ),
            ]),
          ),
        ),
        actions: [
          if (!_group && peer != null && peer.isNotEmpty) ...[
            IconButton(
              tooltip: 'Video call',
              icon: const Icon(CupertinoIcons.videocam_fill),
              onPressed: () => CallService.instance.call(context, threadId: widget.threadId, peerId: peer, peerName: _title, video: true),
            ),
            IconButton(
              tooltip: 'Telepon',
              icon: const Icon(CupertinoIcons.phone_fill),
              onPressed: () => CallService.instance.call(context, threadId: widget.threadId, peerId: peer, peerName: _title, video: false),
            ),
          ],
        ],
      ),
      body: PageGlow(
        accent: AppColors.violet,
        child: Column(children: [
          Expanded(
            child: _loading
                ? const SkeletonList()
                : _error != null
                    ? Center(child: Text(_error!))
                    : _msgs.isEmpty
                        ? const EmptyState(icon: CupertinoIcons.chat_bubble, title: 'Belum ada pesan', message: 'Sapa duluan!')
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                            itemCount: _msgs.length,
                            itemBuilder: (_, i) => _row(i, scheme),
                          ),
          ),
          if (_uploading != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text(_uploading!, style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          _composer(scheme),
        ]),
      ),
    );
  }

  Widget _row(int i, ColorScheme scheme) {
    final m = _msgs[i];
    final at = DateTime.tryParse('${m['created_at']}')?.toLocal();
    final older = i + 1 < _msgs.length ? DateTime.tryParse('${_msgs[i + 1]['created_at']}')?.toLocal() : null;
    final newDay = at != null && (older == null || older.year != at.year || older.month != at.month || older.day != at.day);
    final sameSenderAbove = i + 1 < _msgs.length && _msgs[i + 1]['sender_id'] == m['sender_id'] && !newDay;
    final bubble = '${m['kind']}' == 'call'
        ? _callChip(m, scheme)
        : _SwipeToReply(
            enabled: m['deleted_at'] == null,
            onReply: () => _startReply(m),
            child: GestureDetector(onLongPress: () => _actions(m), child: _bubble(m, scheme, showName: !sameSenderAbove)),
          );
    return Column(children: [
      if (newDay) _dayChip(at, scheme),
      bubble,
      if (i == _lastMineIndex) _seenLabel(m, scheme),
    ]);
  }

  Widget _dayChip(DateTime d, ColorScheme scheme) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day), day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    const bln = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final label = diff == 0 ? 'Hari ini' : diff == 1 ? 'Kemarin' : '${d.day} ${bln[d.month - 1]} ${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      ),
    );
  }

  Widget _callChip(Map<String, dynamic> m, ColorScheme scheme) {
    final missed = '${m['body']}'.contains('tidak terjawab');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(AppRadius.control)),
          // riwayat lama masih menyimpan emoji 📞/📹 di depan teks: dibuang saat ditampilkan
          child: Text('${'${m['body']}'.replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '')} · ${chatTimeLabel(DateTime.tryParse('${m['created_at']}'))}',
              style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w600, color: missed ? AppColors.red : scheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m, ColorScheme scheme, {required bool showName}) {
    final mine = m['sender_id'] == _me;
    final deleted = m['deleted_at'] != null;
    final kind = '${m['kind'] ?? 'text'}';
    final body = '${m['body'] ?? ''}';
    final fg = mine ? Colors.white : scheme.onSurface;
    final sub = mine ? Colors.white70 : scheme.onSurfaceVariant;
    final reply = _find(m['reply_to'] as String?);
    final path = m['attachment_path'] as String?;

    Widget content;
    if (deleted) {
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(CupertinoIcons.nosign, size: 16, color: sub),
        const SizedBox(width: 6),
        Text('Pesan ini telah dihapus', style: TextStyle(fontStyle: FontStyle.italic, color: sub)),
      ]);
    } else {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (kind == 'image' && path != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: ChatImage(path: path)),
        if (kind == 'file' && path != null) ChatFileTile(path: path, name: '${m['attachment_name'] ?? 'Dokumen'}', size: m['attachment_size'] as num?, mine: mine),
        if (kind == 'audio' && path != null) ChatAudioBubble(path: path, durationMs: (m['duration_ms'] as num?)?.toInt(), mine: mine),
        if (body.isNotEmpty && kind != 'audio')
          Padding(
            padding: EdgeInsets.only(top: kind == 'file' ? 6 : 0),
            child: Text(body, style: TextStyle(height: 1.35, color: fg)),
          ),
      ]);
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: EdgeInsets.only(top: showName ? 6 : 2, bottom: 2),
        padding: EdgeInsets.fromLTRB(kind == 'image' && !deleted ? 5 : 12, kind == 'image' && !deleted ? 5 : 8, kind == 'image' && !deleted ? 5 : 12, 6),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest.withValues(alpha: 0.95),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        // lebar gelembung mengikuti isi; jam & centang rata kanan di bawahnya
        child: IntrinsicWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (_group && !mine && showName)
            Padding(
              padding: EdgeInsets.only(bottom: 2, left: kind == 'image' ? 6 : 0),
              child: Text(_names['${m['sender_id']}'] ?? 'Anggota', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, color: scheme.primary)),
            ),
          if (m['reply_to'] != null && !deleted)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
              decoration: BoxDecoration(
                color: (mine ? Colors.white : scheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: mine ? Colors.white : scheme.primary, width: 3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(reply == null ? 'Pesan' : (reply['sender_id'] == _me ? 'Anda' : (_names['${reply['sender_id']}'] ?? 'Anggota')),
                    style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, color: mine ? Colors.white : scheme.primary)),
                Text(_preview(reply), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, color: sub)),
              ]),
            ),
          content,
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(right: kind == 'image' && !deleted ? 6 : 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (m['edited_at'] != null && !deleted) Text('diedit · ', style: TextStyle(fontSize: AppType.micro, color: sub)),
              Text(chatTimeLabel(DateTime.tryParse('${m['created_at']}')), style: TextStyle(fontSize: AppType.micro, color: sub)),
              if (mine && !deleted) ...[
                const SizedBox(width: 4),
                _ticks(m, sub),
              ],
            ]),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _composer(ColorScheme scheme) {
    final hasText = _input.text.trim().isNotEmpty;
    final banner = _editing ?? _replyTo;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (banner != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: scheme.primary, width: 3)),
              ),
              child: Row(children: [
                Icon(_editing != null ? CupertinoIcons.pencil : CupertinoIcons.arrowshape_turn_up_left, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _editing != null ? 'Edit pesan' : 'Membalas ${banner['sender_id'] == _me ? 'diri sendiri' : (_names['${banner['sender_id']}'] ?? 'Anggota')}',
                      style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w800, color: scheme.primary),
                    ),
                    Text(_preview(banner), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Batal',
                  icon: const Icon(CupertinoIcons.xmark, size: 20),
                  onPressed: () => setState(() {
                    if (_editing != null) _input.clear();
                    _editing = null;
                    _replyTo = null;
                  }),
                ),
              ]),
            ),
          if (_recording)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(26)),
              child: Row(children: [
                IconButton(tooltip: 'Buang', icon: const Icon(CupertinoIcons.trash, color: AppColors.red), onPressed: () => _recFinish(send: false)),
                const _RecDot(),
                const SizedBox(width: 8),
                Text(durationLabel(DateTime.now().difference(_recStart ?? DateTime.now())),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 8),
                Expanded(child: Text('Merekam…', style: TextStyle(color: scheme.onSurfaceVariant))),
                IconButton.filled(tooltip: 'Kirim pesan suara', onPressed: () => _recFinish(send: true), icon: const Icon(CupertinoIcons.paperplane_fill)),
              ]),
            )
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (_editing == null)
                IconButton(tooltip: 'Lampirkan', onPressed: _uploading != null ? null : _attachSheet, icon: const Icon(CupertinoIcons.paperclip)),
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: _editing != null ? 'Edit pesan' : 'Tulis pesan',
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (_editing == null && !hasText)
                IconButton(tooltip: 'Kamera', onPressed: _uploading != null ? null : () => _pickImage(ImageSource.camera), icon: const Icon(CupertinoIcons.camera)),
              const SizedBox(width: 4),
              hasText || _editing != null
                  ? IconButton.filled(
                      tooltip: _editing != null ? 'Simpan' : 'Kirim',
                      onPressed: _sending ? null : _send,
                      icon: Icon(_editing != null ? CupertinoIcons.checkmark : CupertinoIcons.paperplane_fill),
                    )
                  : IconButton.filled(
                      tooltip: 'Rekam pesan suara',
                      onPressed: _uploading != null ? null : _recStartTap,
                      icon: const Icon(CupertinoIcons.mic_fill),
                    ),
            ]),
        ]),
      ),
    );
  }
}

/// Geser gelembung ke kanan untuk membalas (seperti WhatsApp). Kembali dengan pegas ease-out.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply, this.enabled = true});
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _dx = 0, _from = 0;
  bool _fired = false;
  static const _trigger = 64.0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _dx = _from * (1 - const Cubic(0.23, 1, 0.32, 1).transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final p = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _back.stop();
        _fired = false;
      },
      onHorizontalDragUpdate: (d) {
        // makin jauh makin berat (redaman di batas)
        final next = (_dx + d.delta.dx * (1 - (_dx / 120).clamp(0.0, 0.8))).clamp(0.0, 96.0);
        setState(() => _dx = next);
        if (!_fired && _dx >= _trigger) {
          _fired = true;
          HapticFeedback.lightImpact();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_fired) widget.onReply();
        _from = _dx;
        _back.forward(from: 0);
      },
      child: Stack(alignment: Alignment.centerLeft, children: [
        Opacity(
          opacity: p,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Transform.scale(scale: 0.6 + 0.4 * p, child: Icon(CupertinoIcons.arrowshape_turn_up_left, color: Theme.of(context).colorScheme.primary)),
          ),
        ),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
      ]),
    );
  }
}

class _RecDot extends StatefulWidget {
  const _RecDot();
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const Icon(CupertinoIcons.circle_fill, color: AppColors.red, size: 14);
    return FadeTransition(opacity: Tween(begin: 0.3, end: 1.0).animate(_c), child: const Icon(CupertinoIcons.circle_fill, color: AppColors.red, size: 14));
  }
}

class _AttachOpt extends StatelessWidget {
  const _AttachOpt({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.button),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 28, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 26)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
