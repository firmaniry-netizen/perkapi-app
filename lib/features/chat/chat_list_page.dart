import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/icon_badge.dart';

String chatTimeLabel(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  final n = DateTime.now();
  if (l.year == n.year && l.month == n.month && l.day == n.day) {
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}';
}

/// Daftar percakapan (pribadi dan grup) dengan penanda belum dibaca.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _ch;

  @override
  void initState() {
    super.initState();
    _load();
    _ch = SupabaseService.client
        .channel('chat-list-${Access.instance.memberId}')
        .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'chat_messages', callback: (_) => _load())
        .subscribe();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await SupabaseService.client.rpc('chat_threads_overview');
      if (mounted) setState(() { _rows = List<Map<String, dynamic>>.from(r as List); _loading = false; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Gagal memuat chat. Jalankan sql/17_chat_signature_search.sql.'; });
    }
  }

  Future<void> _new() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const NewChatPage()));
    if (id != null && mounted) {
      await context.push('/chat/$id');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _new, icon: const Icon(Icons.edit_outlined), label: const Text('Chat baru')),
      body: PageGlow(accent: AppColors.violet, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _rows.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada percakapan. Ketuk "Chat baru" untuk memulai.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant))))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _rows[i];
                          final unread = (r['unread'] as num?)?.toInt() ?? 0;
                          return Card(
                            child: ListTile(
                              onTap: () async {
                                await context.push('/chat/${r['thread_id']}');
                                _load();
                              },
                              leading: IconBadge(r['kind'] == 'group' ? Icons.groups_outlined : Icons.person_outline, size: 46),
                              title: Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700)),
                              subtitle: Text('${r['last_body'] ?? 'Belum ada pesan'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(chatTimeLabel(DateTime.tryParse('${r['last_at']}')), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                if (unread > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
                    )),
    );
  }
}

/// Pilih anggota untuk chat pribadi, atau beberapa anggota untuk grup. Mengembalikan id thread.
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});
  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  List<Map<String, dynamic>> _all = [];
  final Set<String> _picked = {};
  final _search = TextEditingController();
  final _title = TextEditingController();
  bool _group = false, _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    SupabaseService.client.rpc('chat_directory').then((r) {
      if (mounted) setState(() { _all = List<Map<String, dynamic>>.from(r as List); _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    super.dispose();
  }

  void _err() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuat chat.')));

  Future<void> _direct(String id) async {
    setState(() => _busy = true);
    try {
      final t = await SupabaseService.client.rpc('chat_start_direct', params: {'p_other': id});
      if (mounted) Navigator.of(context).pop('$t');
    } catch (_) {
      if (mounted) { setState(() => _busy = false); _err(); }
    }
  }

  Future<void> _createGroup() async {
    if (_title.text.trim().isEmpty || _picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi nama grup dan pilih minimal satu anggota.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final t = await SupabaseService.client.rpc('chat_create_group', params: {'p_title': _title.text.trim(), 'p_members': _picked.toList()});
      if (mounted) Navigator.of(context).pop('$t');
    } catch (_) {
      if (mounted) { setState(() => _busy = false); _err(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = _all.where((m) => q.isEmpty || '${m['name']}'.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Chat baru')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Pribadi')), ButtonSegment(value: true, label: Text('Grup'))],
            selected: {_group},
            onSelectionChanged: (s) => setState(() => _group = s.first),
          ),
        ),
        if (_group)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _title, maxLength: 60, decoration: const InputDecoration(labelText: 'Nama grup'))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Cari anggota', prefixIcon: Icon(Icons.search), isDense: true)),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final id = '${m['member_id']}';
                    return _group
                        ? CheckboxListTile(
                            value: _picked.contains(id),
                            title: Text('${m['name']}'),
                            onChanged: (v) => setState(() => v == true ? _picked.add(id) : _picked.remove(id)),
                          )
                        : ListTile(leading: const IconBadge(Icons.person_outline, size: 40), title: Text('${m['name']}'), onTap: _busy ? null : () => _direct(id));
                  },
                ),
        ),
        if (_group)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _createGroup, child: Text('Buat grup (${_picked.length})'))),
            ),
          ),
      ]),
    );
  }
}
