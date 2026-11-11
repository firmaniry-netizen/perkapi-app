import 'package:flutter/material.dart';
import '../../core/widgets/ios_segmented.dart';
import '../../core/constants/phosphor_icons.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/motion.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/ui_kit.dart';
import '../../core/constants/app_tokens.dart';

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
  final _q = TextEditingController();
  List<Map<String, dynamic>>? _dir; // semua anggota (untuk cari nama yang belum pernah di-chat)
  bool _opening = false;

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
    _q.dispose();
    super.dispose();
  }

  Future<void> _ensureDir() async {
    if (_dir != null) return;
    _dir = const [];
    try {
      final r = await SupabaseService.client.rpc('chat_directory');
      if (mounted) setState(() => _dir = List<Map<String, dynamic>>.from(r as List));
    } catch (_) {}
  }

  Future<void> _openDirect(String memberId) async {
    if (_opening) return;
    _opening = true;
    try {
      final t = await SupabaseService.client.rpc('chat_start_direct', params: {'p_other': memberId});
      if (!mounted) return;
      _q.clear();
      await context.push('/chat/$t');
      _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka chat.')));
    } finally {
      _opening = false;
    }
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
    // Isi digulir DI BELAKANG bar kaca (iOS): kolom cari ikut bergulir sebagai baris pertama.
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Aksi utama di bar atas (gaya iOS), bukan tombol mengambang.
      appBar: GlassAppBar(title: const Text('Chat'), actions: [
        IconButton(tooltip: 'Chat baru', icon: const Icon(Ph.notePencil), onPressed: _new),
      ]),
      body: PageGlow(
        accent: AppColors.violet,
        child: RefreshIndicator.adaptive(
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: _load,
          child: ListView(
            padding: barPad(context, const EdgeInsets.fromLTRB(16, 8, 16, 100)),
            children: [
              TextField(
                controller: _q,
                onChanged: (v) {
                  if (v.trim().length >= 2) _ensureDir();
                  setState(() {});
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau pesan',
                  prefixIcon: const Icon(Ph.magnifyingGlass),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.chip), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(tooltip: 'Hapus', icon: const Icon(Ph.x), onPressed: () => setState(_q.clear)),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              ..._content(scheme),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(ColorScheme scheme) {
    if (_loading) return const [SkeletonList()];
    if (_error != null) {
      return [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))];
    }
    final q = _q.text.trim().toLowerCase();
    final threads = q.isEmpty
        ? _rows
        : _rows.where((r) => '${r['title']}'.toLowerCase().contains(q) || '${r['last_body'] ?? ''}'.toLowerCase().contains(q)).toList();
    // anggota yang cocok namanya tapi belum punya chat pribadi dengan saya
    final directTitles = {for (final r in _rows) if (r['kind'] == 'direct') '${r['title']}'.toLowerCase()};
    final people = q.length < 2
        ? const <Map<String, dynamic>>[]
        : (_dir ?? const <Map<String, dynamic>>[])
            .where((m) => '${m['name']}'.toLowerCase().contains(q) && !directTitles.contains('${m['name']}'.toLowerCase()))
            .take(30)
            .toList();
    if (threads.isEmpty && people.isEmpty) {
      return [
        SizedBox(
          height: 360,
          child: EmptyState(
            icon: Ph.chatsCircle,
            title: q.isEmpty ? 'Belum ada percakapan' : 'Tidak ditemukan',
            message: q.isEmpty ? 'Ketuk "Chat baru" untuk memulai.' : 'Tidak ada yang cocok dengan "${_q.text.trim()}".',
          ),
        ),
      ];
    }
    return [
      if (threads.isNotEmpty) InsetGroup(children: [for (final r in threads) _threadTile(r, scheme)]),
      if (people.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text('Anggota lain', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        ),
        InsetGroup(children: [
          for (final m in people)
            ListTile(
              leading: MemberAvatar(name: '${m['name']}', radius: 22),
              title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Ketuk untuk mulai chat'),
              trailing: const Icon(Ph.chatCircle),
              onTap: () => _openDirect('${m['member_id']}'),
            ),
        ]),
      ],
    ];
  }

  Widget _threadTile(Map<String, dynamic> r, ColorScheme scheme) {
    final unread = (r['unread'] as num?)?.toInt() ?? 0;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () async {
          await context.push('/chat/${r['thread_id']}');
          _load();
        },
        leading: r['kind'] == 'group'
            ? const IconBadge(Ph.usersThree, size: 46)
            : MemberAvatar(name: '${r['title']}', radius: 23),
        title: Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w700)),
        subtitle: Text('${r['last_body'] ?? 'Belum ada pesan'}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(chatTimeLabel(DateTime.tryParse('${r['last_at']}')), style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: AppType.micro, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
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
      appBar: GlassAppBar(title: const Text('Chat baru')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: IosSegmentedButton<bool>(
            segments: const [ButtonSegment(value: false, label: Text('Pribadi')), ButtonSegment(value: true, label: Text('Grup'))],
            selected: {_group},
            onSelectionChanged: (s) => setState(() => _group = s.first),
          ),
        ),
        if (_group)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: _title, maxLength: 60, decoration: const InputDecoration(labelText: 'Nama grup'))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Cari anggota', prefixIcon: Icon(Ph.magnifyingGlass), isDense: true)),
        ),
        Expanded(
          child: _loading
              ? const SkeletonList()
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final id = '${m['member_id']}';
                    return _group
                        ? CheckboxListTile.adaptive(
                            value: _picked.contains(id),
                            title: Text('${m['name']}'),
                            onChanged: (v) => setState(() => v == true ? _picked.add(id) : _picked.remove(id)),
                          )
                        : ListTile(leading: MemberAvatar(name: '${m['name']}', radius: 20), title: Text('${m['name']}'), onTap: _busy ? null : () => _direct(id));
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
