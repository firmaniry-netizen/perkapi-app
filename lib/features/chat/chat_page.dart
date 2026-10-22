import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import 'chat_list_page.dart';

/// Percakapan satu thread: pesan realtime, penanda dibaca, kirim pesan.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.threadId});
  final String threadId;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _db = SupabaseService.client;
  final _input = TextEditingController();
  List<Map<String, dynamic>> _msgs = []; // terbaru di indeks 0
  final Map<String, String> _names = {};
  String _title = 'Chat';
  bool _group = false, _loading = true, _sending = false;
  String? _error;
  RealtimeChannel? _ch;

  String? get _me => Access.instance.memberId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    _input.dispose();
    super.dispose();
  }

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
      final rows = await _db
          .from('chat_messages')
          .select('id,sender_id,body,created_at')
          .eq('thread_id', widget.threadId)
          .order('created_at', ascending: false)
          .limit(150);
      _msgs = List<Map<String, dynamic>>.from(rows as List);
      _ch = _db
          .channel('chat-${widget.threadId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'thread_id', value: widget.threadId),
            callback: (p) => _add(Map<String, dynamic>.from(p.newRecord)),
          )
          .subscribe();
      _markRead();
      if (mounted) setState(() { _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal memuat percakapan.'; });
    }
  }

  void _add(Map<String, dynamic> m) {
    if (!mounted || _msgs.any((e) => e['id'] == m['id'])) return;
    setState(() => _msgs.insert(0, m));
    if (m['sender_id'] != _me) _markRead();
  }

  void _markRead() {
    _db.rpc('chat_mark_read', params: {'p_thread': widget.threadId}).catchError((_) {});
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || _me == null) return;
    setState(() => _sending = true);
    try {
      final r = await _db
          .from('chat_messages')
          .insert({'thread_id': widget.threadId, 'sender_id': _me, 'body': text})
          .select('id,sender_id,body,created_at')
          .single();
      _input.clear();
      _add(Map<String, dynamic>.from(r));
      _markRead();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan gagal terkirim.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: PageGlow(accent: AppColors.violet, child: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        final mine = m['sender_id'] == _me;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: mine ? scheme.primary : scheme.onSurface.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(mine ? 18 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 18),
                              ),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (_group && !mine)
                                Text(_names['${m['sender_id']}'] ?? 'Anggota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.primary)),
                              Text('${m['body']}', style: TextStyle(height: 1.35, color: mine ? Colors.white : null)),
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(chatTimeLabel(DateTime.tryParse('${m['created_at']}')),
                                    style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : scheme.onSurfaceVariant)),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Tulis pesan', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ])),
    );
  }
}
