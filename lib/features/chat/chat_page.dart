import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/ios_dialog.dart';
import '../../core/constants/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/online_service.dart';
import 'chat_prefs.dart';
import 'chat_wallpaper.dart';
import 'emoji_panel.dart';
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

const _cols = 'id,sender_id,body,created_at,kind,attachment_path,attachment_name,attachment_size,attachment_mime,duration_ms,reply_to,edited_at,deleted_at,forwarded';

/// Reaksi cepat di menu tekan lama, seperti WhatsApp.
const _quickReacts = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

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
    _scroll.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted) return;
    // Lawan bicara baru saja offline: "terakhir dilihat" = sekarang (tanpa menunggu server).
    final on = OnlineService.instance.isOnline(_peerId);
    // Bila server menyembunyikan waktunya (privasi), tetap disembunyikan.
    if (_peerWasOnline && !on && _peerLastSeen != null) _peerLastSeen = DateTime.now();
    _peerWasOnline = on;
    setState(() {});
  }

  String? _peerAvatar;

  /// "Terakhir dilihat" lawan bicara (chat pribadi). Null = belum diketahui atau disembunyikan server.
  DateTime? _peerLastSeen;
  bool _peerWasOnline = false;

  /// Panel emoji menggantikan keyboard di bawah kolom pesan.
  bool _emoji = false;

  /// Reaksi: message_id -> (member_id -> emoji).
  final Map<String, Map<String, String>> _reacts = {};

  /// Pesan yang saya bintangi di percakapan ini (pribadi).
  final Set<String> _stars = {};

  /// Pesan yang disematkan di percakapan ini (terlihat semua peserta).
  Map<String, dynamic>? _pinned;

  /// Pesan yang sedang disorot setelah dipilih dari pencarian, bintang, atau banner sematan.
  String? _flashId;
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  /// Latar chat (indeks [ChatWallpaper.names]).
  int _wallpaper = 0;

  /// Notifikasi percakapan ini dibisukan sampai kapan (null = tidak dibisukan).
  DateTime? _mutedUntil;

  Future<void> _loadPeerLastSeen() async {
    final peer = _peerId;
    if (_group || peer == null || peer.isEmpty) return;
    try {
      final r = await _db.rpc('member_last_seen', params: {'p_member': peer});
      final t = r == null ? null : DateTime.tryParse('$r');
      if (t != null && mounted) setState(() => _peerLastSeen = t.toLocal());
    } catch (_) {}
  }

  void _insertEmoji(String e) {
    final v = _input.value;
    final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(s.start, s.end, e);
    _input.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: s.start + e.length));
    setState(() {});
  }

  void _backspace() {
    final v = _input.value;
    final s = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    if (!s.isCollapsed) {
      _input.value = TextEditingValue(text: v.text.replaceRange(s.start, s.end, ''), selection: TextSelection.collapsed(offset: s.start));
    } else if (s.start > 0) {
      // Hapus satu karakter yang terlihat (emoji bisa terdiri dari beberapa kode).
      final before = v.text.substring(0, s.start).characters;
      final cut = before.skipLast(1).toString();
      _input.value = TextEditingValue(text: cut + v.text.substring(s.start), selection: TextSelection.collapsed(offset: cut.length));
    }
    setState(() {});
  }

  void _toggleEmoji() {
    if (_emoji) {
      setState(() => _emoji = false);
      _focus.requestFocus();
    } else {
      _focus.unfocus();
      setState(() => _emoji = true);
    }
  }

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
      _mutedUntil = ChatPrefs.isMuted(t['muted_until']) ? DateTime.tryParse('${t['muted_until']}')?.toLocal() : null;
      final mem = List<Map<String, dynamic>>.from(await _db.rpc('chat_thread_members', params: {'p_thread': widget.threadId}) as List);
      for (final m in mem) {
        _names['${m['member_id']}'] = '${m['name']}';
      }
      final rows = await _db.from('chat_messages').select(_cols).eq('thread_id', widget.threadId).order('created_at', ascending: false).limit(200);
      _msgs = List<Map<String, dynamic>>.from(rows as List);
      await _loadReads();
      await _loadExtras();
      _wallpaper = await ChatWallpaper.load(widget.threadId);
      _subscribe();
      _markRead();
      _loadPeerAvatar();
      _loadPeerLastSeen();
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

  /// Reaksi, bintang, dan pesan tersemat (SQL 49). Bila belum dijalankan, fitur ini diam saja.
  Future<void> _loadExtras() async {
    try {
      final r = await _db.from('chat_reactions').select('message_id,member_id,emoji').eq('thread_id', widget.threadId);
      for (final x in r as List) {
        _reacts.putIfAbsent('${x['message_id']}', () => {})['${x['member_id']}'] = '${x['emoji']}';
      }
      final st = await _db.from('chat_stars').select('message_id').eq('thread_id', widget.threadId);
      _stars
        ..clear()
        ..addAll((st as List).map((e) => '${e['message_id']}'));
      final t = await _db.from('chat_threads').select('pinned_message_id').eq('id', widget.threadId).maybeSingle();
      await _loadPinned(t?['pinned_message_id'] as String?);
    } catch (_) {}
  }

  Future<void> _loadPinned(String? id) async {
    if (id == null) {
      _pinned = null;
    } else {
      _pinned = _find(id) ?? await _db.from('chat_messages').select(_cols).eq('id', id).maybeSingle();
    }
    if (mounted) setState(() {});
  }

  void _setReact(Map<String, dynamic> r) {
    if (!mounted) return;
    setState(() => _reacts.putIfAbsent('${r['message_id']}', () => {})['${r['member_id']}'] = '${r['emoji']}');
  }

  void _dropReact(Map<String, dynamic> r) {
    final map = _reacts['${r['message_id']}'];
    if (map == null || !mounted) return;
    setState(() => map.remove('${r['member_id']}'));
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
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'chat_reactions', filter: filter, callback: (p) => _setReact(p.newRecord))
        .onPostgresChanges(event: PostgresChangeEvent.update, schema: 'public', table: 'chat_reactions', filter: filter, callback: (p) => _setReact(p.newRecord))
        // Event hapus tidak bisa difilter per kolom; yang bukan milik percakapan ini tidak cocok dengan pesan mana pun.
        .onPostgresChanges(event: PostgresChangeEvent.delete, schema: 'public', table: 'chat_reactions', callback: (p) => _dropReact(p.oldRecord))
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_threads',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: widget.threadId),
          callback: (p) {
            final id = p.newRecord['pinned_message_id'] as String?;
            if (id != _pinned?['id']) _loadPinned(id);
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
            _AttachOpt(icon: PhFill.camera, label: 'Kamera', color: AppColors.red, onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            }),
            _AttachOpt(icon: Ph.images, label: 'Galeri', color: AppColors.violet, onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            }),
            _AttachOpt(icon: PhFill.fileText, label: 'Dokumen', color: AppColors.navyAction, onTap: () {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final e in _quickReacts)
                  _ReactButton(
                    emoji: e,
                    selected: _reacts['${m['id']}']?[_me] == e,
                    onTap: () {
                      Navigator.pop(ctx);
                      _react(m, e);
                    },
                  ),
                _ReactButton(
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickReaction(m);
                  },
                ),
              ]),
            ),
          if (!deleted && kind != 'call')
            ListTile(leading: const Icon(Ph.arrowBendUpLeft), title: const Text('Balas'), onTap: () {
              Navigator.pop(ctx);
              _startReply(m);
            }),
          if (!deleted && kind != 'call')
            ListTile(leading: const Icon(Ph.arrowBendUpRight), title: const Text('Teruskan'), onTap: () {
              Navigator.pop(ctx);
              _forward(m);
            }),
          if (!deleted && kind != 'call')
            ListTile(
              leading: Icon(_stars.contains('${m['id']}') ? PhFill.star : Ph.star),
              title: Text(_stars.contains('${m['id']}') ? 'Hapus bintang' : 'Bintangi'),
              onTap: () {
                Navigator.pop(ctx);
                _star(m);
              },
            ),
          if (!deleted && kind != 'call')
            ListTile(
              leading: Icon(_pinned?['id'] == m['id'] ? Ph.pushPinSlash : Ph.pushPin),
              title: Text(_pinned?['id'] == m['id'] ? 'Lepas sematan' : 'Sematkan'),
              onTap: () {
                Navigator.pop(ctx);
                _pin(_pinned?['id'] == m['id'] ? null : m);
              },
            ),
          if (!deleted && '${m['body'] ?? ''}'.isNotEmpty)
            ListTile(leading: const Icon(Ph.copy), title: const Text('Salin teks'), onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: '${m['body']}'));
              _snack('Teks disalin.');
            }),
          if (canEdit)
            ListTile(leading: const Icon(Ph.pencilSimple), title: Text(kind == 'text' ? 'Edit' : 'Edit keterangan'), onTap: () {
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
              leading: const Icon(Ph.trash, color: AppColors.red),
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

  // ---------------------------------------------------------------- reaksi, teruskan, bintang, sematkan
  Future<void> _react(Map<String, dynamic> m, String emoji) async {
    final me = _me;
    if (me == null) return;
    final id = '${m['id']}';
    final cur = _reacts[id]?[me];
    HapticFeedback.selectionClick();
    void apply(String? e) => setState(() {
          final map = _reacts.putIfAbsent(id, () => {});
          if (e == null) {
            map.remove(me);
          } else {
            map[me] = e;
          }
        });
    // Memilih emoji yang sama lagi = membatalkan reaksi (seperti WhatsApp).
    apply(cur == emoji ? null : emoji);
    try {
      if (cur == emoji) {
        await _db.from('chat_reactions').delete().eq('message_id', id).eq('member_id', me);
      } else {
        await _db.from('chat_reactions').upsert({'message_id': id, 'member_id': me, 'thread_id': widget.threadId, 'emoji': emoji});
      }
    } catch (_) {
      if (mounted) apply(cur);
      _snack('Reaksi gagal dikirim.');
    }
  }

  void _pickReaction(Map<String, dynamic> m) {
    showSmoothSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: EmojiPanel(onEmoji: (e) {
          Navigator.pop(ctx);
          _react(m, e);
        }),
      ),
    );
  }

  /// Siapa memberi reaksi apa. Ketuk reaksi sendiri untuk menghapusnya.
  void _showReactions(Map<String, dynamic> m) {
    final map = _reacts['${m['id']}'] ?? const {};
    showSmoothSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${map.length} reaksi', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          for (final e in map.entries)
            ListTile(
              leading: MemberAvatar(name: e.key == _me ? 'Anda' : (_names[e.key] ?? 'Anggota'), radius: 18),
              title: Text(e.key == _me ? 'Anda' : (_names[e.key] ?? 'Anggota')),
              subtitle: e.key == _me ? const Text('Ketuk untuk menghapus') : null,
              trailing: Text(e.value, style: const TextStyle(fontSize: 24)),
              onTap: e.key == _me
                  ? () {
                      Navigator.pop(ctx);
                      _react(m, e.value);
                    }
                  : null,
            ),
        ]),
      ),
    );
  }

  Future<void> _forward(Map<String, dynamic> m) async {
    final me = _me;
    if (me == null) return;
    List<Map<String, dynamic>> threads;
    try {
      threads = List<Map<String, dynamic>>.from(await _db.rpc('chat_threads_overview') as List);
    } catch (_) {
      _snack('Gagal memuat daftar chat.');
      return;
    }
    if (!mounted) return;
    final target = await showSmoothSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Teruskan ke…', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final t in threads)
                  ListTile(
                    leading: t['kind'] == 'group'
                        ? const CircleAvatar(radius: 20, backgroundColor: AppColors.navyAction, child: Icon(PhFill.usersThree, size: 20, color: Colors.white))
                        : MemberAvatar(name: '${t['title']}', radius: 20),
                    title: Text('${t['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.pop(ctx, t),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (target == null) return;
    final tid = '${target['thread_id']}';
    final kind = '${m['kind'] ?? 'text'}';
    setState(() => _uploading = 'Meneruskan pesan…');
    try {
      // Lampiran disalin ke folder percakapan tujuan, karena akses berkas mengikuti keanggotaan percakapan.
      String? path = m['attachment_path'] as String?;
      if (path != null && kind != 'text') {
        final bytes = await _db.storage.from(ChatFiles.bucket).download(path);
        path = await ChatFiles.upload(threadId: tid, memberId: me, bytes: bytes, name: '${m['attachment_name'] ?? 'berkas'}', mime: m['attachment_mime'] as String?);
      }
      final row = await _db
          .from('chat_messages')
          .insert({
            'thread_id': tid,
            'sender_id': me,
            'body': m['body'] ?? '',
            'kind': kind,
            'forwarded': true,
            if (path != null) ...{
              'attachment_path': path,
              'attachment_name': m['attachment_name'],
              'attachment_size': m['attachment_size'],
              'attachment_mime': m['attachment_mime'],
              if (m['duration_ms'] != null) 'duration_ms': m['duration_ms'],
            },
          })
          .select(_cols)
          .single();
      if (tid == widget.threadId) _upsert(Map<String, dynamic>.from(row));
      _snack('Diteruskan ke ${target['title']}.');
    } on ChatUploadException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal meneruskan pesan.');
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _star(Map<String, dynamic> m) async {
    final me = _me;
    if (me == null) return;
    final id = '${m['id']}';
    final on = !_stars.contains(id);
    void apply(bool v) => setState(() {
          if (v) {
            _stars.add(id);
          } else {
            _stars.remove(id);
          }
        });
    apply(on);
    try {
      if (on) {
        await _db.from('chat_stars').insert({'member_id': me, 'message_id': id, 'thread_id': widget.threadId});
      } else {
        await _db.from('chat_stars').delete().eq('member_id', me).eq('message_id', id);
      }
    } catch (_) {
      if (mounted) apply(!on);
      _snack('Gagal menyimpan bintang.');
    }
  }

  Future<void> _pin(Map<String, dynamic>? m) async {
    final old = _pinned;
    setState(() => _pinned = m);
    try {
      await _db.rpc('chat_pin_message', params: {'p_thread': widget.threadId, 'p_message': m?['id']});
    } catch (_) {
      if (mounted) setState(() => _pinned = old);
      _snack(m == null ? 'Gagal melepas sematan.' : 'Gagal menyematkan pesan.');
    }
  }

  /// Gulir ke pesan lalu sorot sebentar.
  void _jumpTo(Map<String, dynamic> m) {
    final id = '${m['id']}';
    final i = _msgs.indexWhere((e) => e['id'] == id);
    if (i < 0) {
      _snack('Pesan ini terlalu lama dan belum dimuat.');
      return;
    }
    setState(() => _flashId = id);
    // Daftar terbalik (indeks 0 di bawah). Lompat kira-kira dulu bila gelembung belum dibangun, lalu pas-kan.
    if (_keys[id]?.currentContext == null && _scroll.hasClients) {
      _scroll.jumpTo((i * 72.0).clamp(0.0, _scroll.position.maxScrollExtent));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[id]?.currentContext;
      if (c != null) {
        Scrollable.ensureVisible(c, alignment: 0.5, duration: Duration(milliseconds: reduceMotion(context) ? 0 : 320), curve: Curves.easeOutCubic);
      }
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _flashId == id) setState(() => _flashId = null);
    });
  }

  // ---------------------------------------------------------------- menu percakapan
  void _menu() {
    final muted = _mutedUntil != null && _mutedUntil!.isAfter(DateTime.now());
    showSmoothSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Ph.magnifyingGlass), title: const Text('Cari'), onTap: () {
            Navigator.pop(ctx);
            _search();
          }),
          ListTile(leading: const Icon(Ph.star), title: const Text('Pesan berbintang'), onTap: () {
            Navigator.pop(ctx);
            _starred();
          }),
          ListTile(leading: const Icon(Ph.paintBrush), title: const Text('Latar chat'), onTap: () {
            Navigator.pop(ctx);
            _pickWallpaper();
          }),
          ListTile(
            leading: Icon(muted ? Ph.bell : Ph.bellSlash),
            title: Text(muted ? 'Bunyikan notifikasi' : 'Bisukan notifikasi'),
            onTap: () {
              Navigator.pop(ctx);
              _toggleMute(muted);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _toggleMute(bool muted) async {
    final until = muted ? null : await ChatPrefs.pickMute(context);
    if (!muted && until == null) return;
    try {
      await ChatPrefs.set(widget.threadId, setMute: true, mutedUntil: until);
      if (mounted) setState(() => _mutedUntil = until);
      _snack(muted ? 'Notifikasi dibunyikan.' : 'Notifikasi dibisukan.');
    } catch (_) {
      _snack('Gagal mengubah notifikasi.');
    }
  }

  Future<void> _search() async {
    final picked = await showSmoothSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChatSearchSheet(threadId: widget.threadId, names: _names, me: _me),
    );
    if (picked != null) _jumpTo(picked);
  }

  Future<void> _starred() async {
    List<Map<String, dynamic>> rows = [];
    if (_stars.isNotEmpty) {
      try {
        rows = List<Map<String, dynamic>>.from(
            await _db.from('chat_messages').select(_cols).inFilter('id', _stars.toList()).order('created_at', ascending: false) as List);
      } catch (_) {
        _snack('Gagal memuat pesan berbintang.');
        return;
      }
    }
    if (!mounted) return;
    final picked = await showSmoothSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pesan berbintang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Text('Belum ada. Tekan lama sebuah pesan, lalu pilih Bintangi.', textAlign: TextAlign.center),
              )
            else
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final r in rows)
                    ListTile(
                      leading: const Icon(PhFill.star, color: AppColors.gold),
                      title: Text(r['sender_id'] == _me ? 'Anda' : (_names['${r['sender_id']}'] ?? 'Anggota')),
                      subtitle: Text(_preview(r), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(chatTimeLabel(DateTime.tryParse('${r['created_at']}'))),
                      onTap: () => Navigator.pop(ctx, r),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
    if (picked != null) _jumpTo(picked);
  }

  void _pickWallpaper() {
    showSmoothSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Latar chat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (var i = 0; i < ChatWallpaper.names.length; i++)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _wallpaper = i);
                    ChatWallpaper.save(widget.threadId, i);
                  },
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 64,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: ChatWallpaper.gradient(i),
                        color: i == 0 ? Theme.of(ctx).scaffoldBackgroundColor : null,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: i == _wallpaper ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.outlineVariant,
                          width: i == _wallpaper ? 2.5 : 1,
                        ),
                      ),
                      child: i == _wallpaper ? const Icon(PhFill.checkCircle, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(ChatWallpaper.names[i], style: const TextStyle(fontSize: AppType.caption)),
                  ]),
                ),
            ]),
          ]),
        ),
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
      builder: (c) => IosDialog(
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
    if (OnlineService.instance.isOnline(_peerId)) return 'online';
    final seen = _peerLastSeen;
    return seen == null ? '' : chatLastSeenLabel(seen);
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
    if (!two) return Icon(Ph.check, size: 15, color: c);
    return SizedBox(
      width: 21,
      height: 15,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 0, top: 0, child: Icon(Ph.check, size: 15, color: c)),
        Positioned(left: 6, top: 0, child: Icon(Ph.check, size: 15, color: c)),
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
                  ? const CircleAvatar(radius: 18, backgroundColor: AppColors.navyAction, child: Icon(PhFill.usersThree, size: 20, color: Colors.white))
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
              icon: const Icon(PhFill.videoCamera),
              onPressed: () => CallService.instance.call(context, threadId: widget.threadId, peerId: peer, peerName: _title, video: true),
            ),
            IconButton(
              tooltip: 'Telepon',
              icon: const Icon(PhFill.phone),
              onPressed: () => CallService.instance.call(context, threadId: widget.threadId, peerId: peer, peerName: _title, video: false),
            ),
          ],
          IconButton(tooltip: 'Lainnya', icon: const Icon(Ph.dotsThree), onPressed: _loading ? null : _menu),
        ],
      ),
      body: _background(
        Column(children: [
          if (_pinned != null) _pinBanner(scheme),
          Expanded(
            child: _loading
                ? const SkeletonList()
                : _error != null
                    ? Center(child: Text(_error!))
                    : _msgs.isEmpty
                        ? const EmptyState(icon: Ph.chatCircle, title: 'Belum ada pesan', message: 'Sapa duluan!')
                        : ListView.builder(
                            controller: _scroll,
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
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2)),
                const SizedBox(width: 10),
                Expanded(child: Text(_uploading!, style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          _composer(scheme),
        ]),
      ),
    );
  }

  Widget _background(Widget child) {
    final g = ChatWallpaper.gradient(_wallpaper);
    if (g == null) return PageGlow(accent: AppColors.violet, child: child);
    return DecoratedBox(decoration: BoxDecoration(gradient: g), child: child);
  }

  Widget _pinBanner(ColorScheme scheme) {
    final p = _find(_pinned!['id'] as String?) ?? _pinned!;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      child: InkWell(
        onTap: () => _jumpTo(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Row(children: [
            Icon(PhFill.pushPin, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Pesan disematkan', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: scheme.primary)),
                Text(_preview(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: scheme.onSurfaceVariant)),
              ]),
            ),
            IconButton(tooltip: 'Lepas sematan', icon: const Icon(Ph.x, size: 18), onPressed: () => _pin(null)),
          ]),
        ),
      ),
    );
  }

  Widget _row(int i, ColorScheme scheme) {
    final m = _msgs[i];
    final at = DateTime.tryParse('${m['created_at']}')?.toLocal();
    final older = i + 1 < _msgs.length ? DateTime.tryParse('${_msgs[i + 1]['created_at']}')?.toLocal() : null;
    final newDay = at != null && (older == null || older.year != at.year || older.month != at.month || older.day != at.day);
    final sameSenderAbove = i + 1 < _msgs.length && _msgs[i + 1]['sender_id'] == m['sender_id'] && !newDay;
    final id = '${m['id']}';
    final reacts = m['deleted_at'] == null ? (_reacts[id] ?? const <String, String>{}) : const <String, String>{};
    final bubble = '${m['kind']}' == 'call'
        ? _callChip(m, scheme)
        : _SwipeToReply(
            enabled: m['deleted_at'] == null,
            onReply: () => _startReply(m),
            child: GestureDetector(onLongPress: () => _actions(m), child: _bubble(m, scheme, showName: !sameSenderAbove)),
          );
    return Column(children: [
      if (newDay) _dayChip(at, scheme),
      // Sorotan singkat saat pesan dipilih dari pencarian, bintang, atau sematan.
      AnimatedContainer(
        key: _keys.putIfAbsent(id, GlobalKey.new),
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _flashId == id ? scheme.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: bubble,
      ),
      if (reacts.isNotEmpty) _reactionChip(m, reacts, scheme),
      if (i == _lastMineIndex) _seenLabel(m, scheme),
    ]);
  }

  /// Reaksi di bawah gelembung: emoji unik (maks. 3) dan jumlahnya, seperti WhatsApp.
  Widget _reactionChip(Map<String, dynamic> m, Map<String, String> reacts, ColorScheme scheme) {
    final mine = m['sender_id'] == _me;
    final counts = <String, int>{};
    for (final e in reacts.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3).map((e) => e.key).join();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Transform.translate(
        offset: const Offset(0, -6),
        child: GestureDetector(
          onTap: () => _showReactions(m),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.chip),
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(top, style: const TextStyle(fontSize: 14)),
              if (reacts.length > 1) ...[
                const SizedBox(width: 3),
                Text('${reacts.length}', style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
              ],
            ]),
          ),
        ),
      ),
    );
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
        Icon(Ph.prohibit, size: 16, color: sub),
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
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
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
              child: Text(_names['${m['sender_id']}'] ?? 'Anggota', style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: scheme.primary)),
            ),
          if (m['forwarded'] == true && !deleted)
            Padding(
              padding: EdgeInsets.only(bottom: 3, left: kind == 'image' ? 6 : 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Ph.arrowBendUpRight, size: 13, color: sub),
                const SizedBox(width: 4),
                Text('Diteruskan', style: TextStyle(fontSize: AppType.caption, fontStyle: FontStyle.italic, color: sub)),
              ]),
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
                    style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: mine ? Colors.white : scheme.primary)),
                Text(_preview(reply), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, color: sub)),
              ]),
            ),
          content,
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(right: kind == 'image' && !deleted ? 6 : 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_stars.contains('${m['id']}') && !deleted) ...[
                Icon(PhFill.star, size: 11, color: sub),
                const SizedBox(width: 3),
              ],
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
                borderRadius: BorderRadius.circular(14),
                border: Border(left: BorderSide(color: scheme.primary, width: 3)),
              ),
              child: Row(children: [
                Icon(_editing != null ? Ph.pencilSimple : Ph.arrowBendUpLeft, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _editing != null ? 'Edit pesan' : 'Membalas ${banner['sender_id'] == _me ? 'diri sendiri' : (_names['${banner['sender_id']}'] ?? 'Anggota')}',
                      style: TextStyle(fontSize: AppType.caption, fontWeight: FontWeight.w700, color: scheme.primary),
                    ),
                    Text(_preview(banner), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Batal',
                  icon: const Icon(Ph.x, size: 20),
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
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(28)),
              child: Row(children: [
                IconButton(tooltip: 'Buang', icon: const Icon(Ph.trash, color: AppColors.red), onPressed: () => _recFinish(send: false)),
                const _RecDot(),
                const SizedBox(width: 8),
                Text(durationLabel(DateTime.now().difference(_recStart ?? DateTime.now())),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(width: 8),
                Expanded(child: Text('Merekam…', style: TextStyle(color: scheme.onSurfaceVariant))),
                IconButton.filled(tooltip: 'Kirim pesan suara', onPressed: () => _recFinish(send: true), icon: const Icon(PhFill.paperPlaneRight)),
              ]),
            )
          else
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (_editing == null)
                IconButton(tooltip: 'Lampirkan', onPressed: _uploading != null ? null : _attachSheet, icon: const Icon(Ph.paperclip)),
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  // Mengetuk kolom pesan saat panel emoji terbuka: kembali ke keyboard.
                  onTap: () {
                    if (_emoji) setState(() => _emoji = false);
                  },
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    // Tombol emoji di dalam kolom, kiri (seperti WhatsApp). Saat panel terbuka berganti ikon keyboard.
                    prefixIcon: IconButton(
                      tooltip: _emoji ? 'Keyboard' : 'Emoji',
                      onPressed: _toggleEmoji,
                      icon: Icon(_emoji ? Ph.keyboard : Ph.smiley),
                    ),
                  ),
                ),
              ),
              if (_editing == null && !hasText)
                IconButton(tooltip: 'Kamera', onPressed: _uploading != null ? null : () => _pickImage(ImageSource.camera), icon: const Icon(Ph.camera)),
              const SizedBox(width: 4),
              hasText || _editing != null
                  ? IconButton.filled(
                      tooltip: _editing != null ? 'Simpan' : 'Kirim',
                      onPressed: _sending ? null : _send,
                      icon: Icon(_editing != null ? Ph.check : PhFill.paperPlaneRight),
                    )
                  : IconButton.filled(
                      tooltip: 'Rekam pesan suara',
                      onPressed: _uploading != null ? null : _recStartTap,
                      icon: const Icon(PhFill.microphone),
                    ),
            ]),
          if (_emoji && !_recording) EmojiPanel(onEmoji: _insertEmoji, onBackspace: _backspace),
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
            child: Transform.scale(scale: 0.6 + 0.4 * p, child: Icon(Ph.arrowBendUpLeft, color: Theme.of(context).colorScheme.primary)),
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
    if (reduceMotion(context)) return const Icon(PhFill.circle, color: AppColors.red, size: 14);
    return FadeTransition(opacity: Tween(begin: 0.3, end: 1.0).animate(_c), child: const Icon(PhFill.circle, color: AppColors.red, size: 14));
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

/// Tombol emoji di baris reaksi menu tekan lama. Tanpa [emoji] = tombol "+" untuk emoji lain.
class _ReactButton extends StatelessWidget {
  const _ReactButton({this.emoji, this.selected = false, required this.onTap});
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: emoji == null ? 'Emoji lain' : 'Reaksi $emoji',
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.primary.withValues(alpha: 0.18) : (emoji == null ? scheme.surfaceContainerHighest : null),
          ),
          child: emoji == null ? Icon(Ph.plus, size: 20, color: scheme.onSurfaceVariant) : Text(emoji!, style: const TextStyle(fontSize: 26)),
        ),
      ),
    );
  }
}

/// Cari teks di dalam satu percakapan (di server, jadi pesan lama ikut tercari). Mengembalikan pesan yang dipilih.
class _ChatSearchSheet extends StatefulWidget {
  const _ChatSearchSheet({required this.threadId, required this.names, required this.me});
  final String threadId;
  final Map<String, String> names;
  final String? me;
  @override
  State<_ChatSearchSheet> createState() => _ChatSearchSheetState();
}

class _ChatSearchSheetState extends State<_ChatSearchSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _hits = [];
  bool _busy = false;
  String _last = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(v.trim()));
  }

  Future<void> _run(String q) async {
    _last = q;
    if (q.length < 2) {
      setState(() => _hits = []);
      return;
    }
    setState(() => _busy = true);
    try {
      // % dan _ adalah karakter khusus ILIKE: di-escape agar dicari apa adanya.
      final safe = q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
      final r = await SupabaseService.client
          .from('chat_messages')
          .select(_cols)
          .eq('thread_id', widget.threadId)
          .isFilter('deleted_at', null)
          .ilike('body', '%$safe%')
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted && _last == q) setState(() => _hits = List<Map<String, dynamic>>.from(r as List));
    } catch (_) {
      if (mounted) setState(() => _hits = []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _q.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _q,
                autofocus: true,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari di percakapan ini',
                  prefixIcon: const Icon(Ph.magnifyingGlass),
                  isDense: true,
                  suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator.adaptive(strokeWidth: 2)) : null,
                ),
              ),
            ),
            Expanded(
              child: q.length < 2
                  ? Center(child: Text('Ketik minimal 2 huruf.', style: TextStyle(color: scheme.onSurfaceVariant)))
                  : _hits.isEmpty && !_busy
                      ? Center(child: Text('Tidak ada pesan yang cocok.', style: TextStyle(color: scheme.onSurfaceVariant)))
                      : ListView.builder(
                          itemCount: _hits.length,
                          itemBuilder: (_, i) {
                            final m = _hits[i];
                            final who = m['sender_id'] == widget.me ? 'Anda' : (widget.names['${m['sender_id']}'] ?? 'Anggota');
                            return ListTile(
                              title: Text(who, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${m['body']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text(chatTimeLabel(DateTime.tryParse('${m['created_at']}')), style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
                              onTap: () => Navigator.pop(context, m),
                            );
                          },
                        ),
            ),
          ]),
        ),
      ),
    );
  }
}
