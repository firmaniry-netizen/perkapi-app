import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../shared/models/modules.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/widgets/ui_kit.dart';

/// Pencarian global lintas modul (debounce). Hasil tetap dibatasi RLS.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _Hit {
  _Hit(this.module, this.id, this.title);
  final String module, id, title;
}

class _SearchPageState extends State<SearchPage> {
  // (modul, tabel, kolom judul, rute modul)
  static const _targets = [
    ('Anggota', 'members', 'full_name', 'members'),
    ('Catatan', 'personal_notes', 'title', 'notes'),
    ('Pengumuman', 'announcements', 'title', 'announcements'),
    ('Event', 'events', 'title', 'events'),
    ('Forum', 'forum_posts', 'title', 'forum'),
    ('Buku Saku Org.', 'pocket_book_contents', 'title', 'org_book'),
  ];
  Timer? _t;
  final _hits = <_Hit>[];
  String? _filter;
  bool _loading = false;
  String _q = '';

  void _onChanged(String v) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 450), () => _run(v));
  }

  Future<void> _run(String raw) async {
    final q = raw.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
    _q = q;
    if (q.length < 2) {
      setState(() => _hits.clear());
      return;
    }
    setState(() => _loading = true);
    final out = <_Hit>[];
    await Future.wait(_targets.where((t) => _filter == null || _filter == t.$1).map((t) async {
      try {
        final rows = await SupabaseService.client
            .from(t.$2)
            .select('id,${t.$3}')
            .ilike(t.$3, '%$q%')
            .limit(5);
        for (final r in rows) {
          out.add(_Hit(t.$4, '${r['id']}', '${r[t.$3]}'));
        }
      } catch (_) {/* tabel tidak boleh diakses / tidak ada: lewati */}
    }));
    if (!mounted || q != _q) return;
    setState(() {
      _hits
        ..clear()
        ..addAll(out);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pencarian')),
        body: PageGlow(accent: AppColors.sky, child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(hintText: 'Cari di semua modul', prefixIcon: Icon(Icons.search), isDense: true),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                    label: const Text('Semua'),
                    selected: _filter == null,
                    onSelected: (_) {
                      setState(() => _filter = null);
                      _run(_q);
                    }),
              ),
              for (final t in _targets)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                      label: Text(t.$1),
                      selected: _filter == t.$1,
                      onSelected: (_) {
                        setState(() => _filter = t.$1);
                        _run(_q);
                      }),
                ),
            ]),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _hits.isEmpty
                ? EmptyState(message: _q.length < 2 ? 'Ketik minimal 2 huruf' : 'Tidak ada hasil', icon: Icons.search_off)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: _hits.length,
                    itemBuilder: (_, i) {
                      final h = _hits[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          radius: 20,
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            minTileHeight: 64,
                            leading: Icon(modules[h.module]?.icon ?? Icons.search, color: Theme.of(context).colorScheme.primary),
                            title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(modules[h.module]?.title ?? h.module),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push('/module/${h.module}/${h.id}'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ])),
      );
}
