import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/widgets/ios_dialog.dart';
import '../../core/constants/phosphor_icons.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/smooth_overlays.dart';
import '../../core/widgets/swipe_row.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/models/modules.dart';
import '../../shared/repositories/data_repository.dart';
import '../../shared/widgets/state_widgets.dart';
import '../../core/services/offline_cache.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/utils/format_id.dart';

/// Daftar generik dengan search (debounce), pagination, pull-to-refresh,
/// state loading/empty/error. Dipakai di banyak modul.
class ModuleListView extends StatefulWidget {
  const ModuleListView({super.key, required this.module, this.showAdd = true, this.header});
  final ModuleDef module;

  /// Kepala opsional (mis. ScreenHero) yang ikut bergulir di atas kolom cari.
  final Widget? header;
  final bool showAdd;

  @override
  State<ModuleListView> createState() => _ModuleListViewState();
}

class _ModuleListViewState extends State<ModuleListView> {
  static const _pageSize = 20;
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  Timer? _debounce;
  String _q = '';
  bool _loading = true, _more = true, _loadingMore = false;
  String? _error;

  ModuleDef get m => widget.module;
  bool get _canWrite => !m.readOnly && Access.instance.can(m.writePerm);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Hapus satu notifikasi: baris langsung hilang, lalu dihapus di server. Gagal = baris dikembalikan.
  Future<void> _deleteNotif(Map<String, dynamic> row) async {
    final at = _items.indexOf(row);
    if (at < 0) return;
    setState(() => _items.removeAt(at));
    try {
      await DataRepository.deleteNotification('${row['id']}');
    } on DataException catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(at > _items.length ? _items.length : at, row));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Hapus semua notifikasi, setelah konfirmasi (tidak bisa dibatalkan).
  Future<void> _deleteAllNotifs() async {
    final ok = await showSmoothDialog<bool>(
      context: context,
      builder: (c) => IosDialog(
        title: const Text('Hapus semua notifikasi?'),
        content: const Text('Semua notifikasi Anda akan dihapus permanen dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n = await DataRepository.deleteAllNotifications();
      if (!mounted) return;
      // Nol baris terhapus padahal daftar berisi: izin hapus di server belum dipasang.
      if (n == 0 && _items.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Notifikasi belum bisa dihapus. Pengurus perlu menjalankan sql/47_hapus_notifikasi.sql di Supabase.')));
      }
    } on DataException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await DataRepository.list(m, q: _q, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rows);
        _more = rows.length == _pageSize;
        _loading = false;
      });
    } on DataException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_more || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await DataRepository.list(m, q: _q, offset: _items.length, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _more = rows.length == _pageSize;
      });
    } on DataException {
      // abaikan; pengguna bisa scroll ulang
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _q = v;
      _refresh();
    });
  }

  Future<void> _open(Map<String, dynamic>? row) async {
    final id = row?['id'];
    final changed = await context.push<bool>(
      id == null ? '/module/${m.id}/new' : '/module/${m.id}/$id',
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Satu gulir untuk semua: kepala (cari, mode offline) ikut bergulir sehingga di halaman dengan
    // extendBodyBehindAppBar isi lewat DI BELAKANG bar kaca. Di halaman biasa padding atas = 0.
    final top = MediaQuery.paddingOf(context).top;
    final tools = m.markAllRead || (m.id == 'notifications' && _items.isNotEmpty) || (widget.showAdd && _canWrite);
    final list = RefreshIndicator.adaptive(
      edgeOffset: top,
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: top)),
          if (widget.header != null) SliverToBoxAdapter(child: widget.header!),
          SliverToBoxAdapter(
            child: ValueListenableBuilder<bool>(
          valueListenable: OfflineCache.offline,
          builder: (_, off, __) => (off && m.offlineCache)
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Icon(Ph.wifiSlash, size: 18, color: AppColors.amber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Mode offline • menampilkan data tersimpan terakhir. Tarik ke bawah untuk menyegarkan.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: AppType.caption, height: 1.35)),
                    ),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
          ),
          // Tombol aksi daftar (rata kanan). Kolom cari pindah ke kapsul kaca di bawah layar.
          if (tools)
          SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (m.markAllRead)
              IconButton(
                tooltip: 'Tandai semua dibaca',
                icon: const Icon(Ph.check),
                onPressed: () async {
                  try {
                    await DataRepository.markAllNotificationsRead();
                  } on DataException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  }
                  _refresh();
                },
              ),
            if (m.id == 'notifications' && _items.isNotEmpty)
              IconButton(tooltip: 'Hapus semua notifikasi', icon: const Icon(Ph.trash), onPressed: _deleteAllNotifs),
            if (widget.showAdd && _canWrite)
              GradientIconButton(
                tooltip: 'Tambah',
                icon: Ph.plus,
                onTap: () => _open(null),
              ),
          ]),
        ),
          ),
          ..._slivers(),
        ],
      ),
    );
    // iOS 26/27: kolom cari berupa kapsul kaca mengambang di bawah layar, di atas tab bar dan area aman.
    // Scaffold dengan extendBody menaruh tinggi tab bar di padding bawah, jadi SafeArea otomatis melewatinya.
    return Stack(children: [
      Positioned.fill(child: list),
      Positioned(
        left: 16,
        right: 16,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LiquidGlass(
              radius: 24,
              blur: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari ${m.title.toLowerCase()}',
                  prefixIcon: const Icon(Ph.magnifyingGlass, size: 20),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  /// Keadaan kosong per modul + satu tombol aksi bila pengguna boleh menambah data.
  Widget _empty() {
    if (_q.isNotEmpty) {
      return const EmptyState(icon: Ph.magnifyingGlass, title: 'Tidak ditemukan', message: 'Coba kata kunci lain atau periksa ejaan.');
    }
    final (title, msg, cta) = switch (m.id) {
      'events' => ('Belum ada agenda', 'Rapat, pelatihan, dan kegiatan organisasi akan tampil di sini.', 'Buat agenda'),
      'forum' => ('Forum masih sepi', 'Mulai diskusi pertama tentang kepailitan, PKPU, atau organisasi.', 'Mulai diskusi'),
      'notes' => ('Buku saku Anda kosong', 'Simpan catatan, pasal penting, dan pengingat pribadi di sini.', 'Tulis catatan'),
      'announcements' => ('Belum ada pengumuman', 'Pengumuman resmi dari pengurus akan tampil di sini.', 'Buat pengumuman'),
      'notifications' => ('Tidak ada notifikasi', 'Aktivitas akun Anda (persetujuan, pengingat, balasan) akan muncul di sini.', ''),
      'members' => ('Belum ada anggota', 'Anggota yang sudah disetujui akan tampil di sini.', 'Tambah anggota'),
      'branches' => ('Belum ada cabang', 'Tambahkan cabang agar anggota dapat memilih cabangnya.', 'Tambah cabang'),
      'org_book' => ('Buku saku organisasi kosong', 'SOP, panduan, dan FAQ organisasi akan tampil di sini.', 'Tambah isi'),
      _ => ('Belum ada data', 'Data akan tampil di sini setelah ditambahkan.', 'Tambah data'),
    };
    final can = widget.showAdd && _canWrite && cta.isNotEmpty;
    return EmptyState(
      icon: m.icon,
      title: title,
      message: msg,
      actionLabel: can ? cta : null,
      onAction: can ? () => _open(null) : null,
    );
  }

  List<Widget> _slivers() {
    if (_loading) return const [SliverToBoxAdapter(child: SkeletonList())];
    if (_error != null) return [SliverFillRemaining(hasScrollBody: false, child: ErrorState(message: _error!, onRetry: _refresh))];
    if (_items.isEmpty) return [SliverFillRemaining(hasScrollBody: false, child: _empty())];
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
        sliver: SliverList.separated(
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final row = _items[i];
          // Kartu khusus untuk modul yang isinya punya "bentuk" sendiri (agenda, diskusi, notifikasi).
          if (m.id == 'events') return Reveal(index: i, child: _EventCard(row: row, onTap: () => _open(row)));
          if (m.id == 'forum') return Reveal(index: i, child: _ThreadCard(row: row, onTap: () => _open(row)));
          if (m.id == 'notifications') {
            // Geser ke kiri (atau tekan lama) untuk menghapus.
            return Reveal(
              index: i,
              child: SwipeRow(
                key: ValueKey(row['id']),
                endAction: SwipeAction(label: 'Hapus', icon: Ph.trash, color: AppColors.red, removes: true, onCommit: () => _deleteNotif(row)),
                child: _NotifCard(row: row, onTap: () => _open(row)),
              ),
            );
          }
          final title = fmtValue(row[m.titleKey]);
          final sub = m.subtitleKeys
              .map((k) => fmtValue(row[k]))
              .where((s) => s.isNotEmpty)
              .join(' • ');
          final status = m.statusKey == null ? '' : fmtValue(row[m.statusKey]);
          final scheme = Theme.of(context).colorScheme;
          final tone = AppColors.forKey(m.id);
          final dark = Theme.of(context).brightness == Brightness.dark;
          return Reveal(
            index: i,
            child: AppCard(
            wash: tone,
            padding: const EdgeInsets.all(16),
            onTap: () => _open(row),
            child: Stack(children: [
              Padding(
                padding: EdgeInsets.only(left: status.isEmpty ? 0 : 12),
                child: Row(children: [
              if (m.id == 'members')
                MemberAvatar(name: title, path: row['avatar_path'] as String?, radius: 24)
              else
                SolidTile(icon: m.icon, color: tone, size: 48, radius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title.isEmpty ? '(tanpa judul)' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.lead)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppType.small, color: scheme.onSurfaceVariant)),
                  ],
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    StatusChip(status),
                  ],
                ]),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.soft(tone, dark: dark), shape: BoxShape.circle),
                child: Icon(Ph.arrowRight, size: 16, color: AppColors.onSoft(tone, dark: dark)),
              ),
                ]),
              ),
              if (status.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 2,
                  bottom: 2,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: StatusChip.toneFor(status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
          ),
          );
        },
        ),
      ),
    ];
  }
}


/// Agenda: blok tanggal besar (huruf judul situs, emas), jam & lokasi, penanda "Hari ini" / "Selesai" / "Di situs".
class _EventCard extends StatelessWidget {
  const _EventCard({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final start = FmtId.parse(row['starts_at']);
    final end = FmtId.parse(row['ends_at']);
    final timed = FmtId.hasTime(row['starts_at']);
    final now = DateTime.now();
    final past = (end ?? start) != null && (end ?? start)!.isBefore(DateTime(now.year, now.month, now.day));
    final today = start != null && FmtId.relativeDay(start) == 'Hari ini';
    final gold = dark ? AppColors.gold : AppColors.goldDeep;
    final chips = <Widget>[
      if (today) const _MiniChip('Hari ini', AppColors.red),
      if (past) const _MiniChip('Selesai', Color(0xFF6B7591)),
      if (row['is_public'] == true) const _MiniChip('Di situs', AppColors.teal, icon: Ph.globe),
    ];
    return Opacity(
      opacity: past ? 0.62 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.soft(gold, dark: dark),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Column(children: [
              Text(start == null ? '-' : '${start.day}', style: AppType.headline(26, color: gold, height: 1)),
              const SizedBox(height: 2),
              Text(start == null ? '' : FmtId.months[start.month - 1].toUpperCase(),
                  style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, letterSpacing: 1, color: gold)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['title'] ?? '(tanpa judul)'}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.lead, height: 1.25)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Ph.clock, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    start == null ? 'Waktu belum diisi' : (timed ? '${FmtId.days[start.weekday - 1]} • ${FmtId.time(start)}' : FmtId.daysLong[start.weekday - 1]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppType.small, color: scheme.onSurfaceVariant),
                  ),
                ),
              ]),
              if ('${row['location'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Ph.mapPinLine, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('${row['location']}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: scheme.onSurfaceVariant)),
                  ),
                ]),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Diskusi forum: lingkaran inisial kategori, judul, cuplikan isi, dan waktu relatif.
class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cat = '${row['category'] ?? 'Diskusi'}';
    final tone = switch (cat) {
      'Kepailitan' => AppColors.navyAction,
      'PKPU' => AppColors.teal,
      'Organisasi' => AppColors.goldDeep,
      'Pembelajaran' => AppColors.sky,
      'Pengumuman' => AppColors.red,
      _ => AppColors.violet,
    };
    final body = '${row['body'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SolidTile(icon: PhFill.chatsCircle, color: tone, size: 44, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: _MiniChip(cat, tone)),
              const SizedBox(width: 8),
              Text(agoId(FmtId.parse(row['created_at'])), style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Text('${row['title'] ?? '(tanpa judul)'}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: AppType.lead, height: 1.25)),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, height: 1.4, color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Notifikasi: titik & huruf tebal bila belum dibaca, waktu relatif.
class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.row, required this.onTap});
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = row['is_read'] == false;
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: unread ? Color.alphaBlend(AppColors.navyAction.withValues(alpha: 0.07), scheme.surface) : null,
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SolidTile(icon: PhFill.bell, color: AppColors.navyAction, size: 40, radius: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${row['title'] ?? 'Notifikasi'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600, fontSize: AppType.lead)),
            if ('${row['body'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text('${row['body']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.small, color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 4),
            Text(agoId(FmtId.parse(row['created_at'])), style: TextStyle(fontSize: AppType.caption, color: scheme.onSurfaceVariant)),
          ]),
        ),
        if (unread)
          Container(
            margin: const EdgeInsets.only(left: 8, top: 6),
            width: 9,
            height: 9,
            decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
          ),
      ]),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.text, this.color, {this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppColors.onSoft(color, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.soft(color, dark: dark), borderRadius: BorderRadius.circular(AppRadius.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppType.micro, fontWeight: FontWeight.w700, color: fg)),
        ),
      ]),
    );
  }
}
