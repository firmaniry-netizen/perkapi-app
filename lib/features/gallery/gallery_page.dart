import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/page_glow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/upload_helper.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/nav_clearance.dart';
import '../../core/widgets/ui_kit.dart';
import '../../shared/widgets/state_widgets.dart';
import '../news/news_detail_page.dart';
import '../news/news_post.dart';
import '../news/news_widgets.dart';

/// Berita & Dokumentasi: satu berita = judul + isi tulisan + beberapa foto.
/// Semua pengguna dapat membaca dan menulis berita; HAPUS berita/foto hanya admin.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, this.autoAdd = false, this.openPostId});
  final bool autoAdd;

  /// Bila diisi (mis. dari tautan/notifikasi), berita dengan id ini langsung dibuka setelah daftar termuat.
  final String? openPostId;
  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _Draft {
  _Draft(this.photos, this.title, this.body, this.album, {this.web = false});
  final List<PlatformFile> photos;
  final String title, body, album;
  /// Terbitkan juga di situs resmi (SQL 37). Database hanya menerima ini dari admin.
  final bool web;
}

String _uuid() {
  final r = Random.secure();
  String h(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${'89ab'[r.nextInt(4)]}${h(3)}-${h(12)}';
}

class _GalleryPageState extends State<GalleryPage> {
  static const _bucket = 'gallery';
  static const _maxBytes = 10 * 1024 * 1024;
  final _db = SupabaseService.client;

  NewsFeed? _feed;
  String? _album; // null = semua
  bool _loading = true;
  String? _error;
  bool _deepLinkDone = false;

  List<NewsPost> get _all => _feed?.posts ?? const [];
  Map<String, String> get _urls => _feed?.urls ?? const {};
  bool get _isAdmin => Access.instance.isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.autoAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _compose();
      });
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _why(Object e) => e is StorageException
      ? e.message
      : e is PostgrestException
          ? e.message
          : '$e';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Daftar hanya butuh foto sampul; seluruh foto ditandatangani saat berita dibuka.
      _feed = await NewsRepository.load(coversOnly: true);
    } catch (_) {
      _error = 'Gagal memuat berita. Pastikan skrip sql/18_gallery.sql, 20_gallery_news.sql, dan 21_news_admin.sql sudah dijalankan.';
    }
    if (mounted) setState(() => _loading = false);
    _openDeepLink();
  }

  void _openDeepLink() {
    final id = widget.openPostId;
    if (id == null || id.isEmpty || _deepLinkDone) return;
    final i = _all.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _deepLinkDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(_all[i]);
    });
  }

  List<String> get _albums => ({for (final p in _all) p.album}).toList()..sort();
  List<NewsPost> get _shown => _album == null ? _all : _all.where((p) => p.album == _album).toList();

  Future<void> _compose() async {
    if (Access.instance.memberId == null) {
      _snack('Akun Anda belum terhubung ke data anggota, jadi belum bisa mengunggah.');
      return;
    }
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ComposePage(albums: _albums, initialAlbum: _album ?? 'Umum', onPublish: _publish, canWeb: _isAdmin),
    ));
    if (ok == true) {
      _snack('Berita diterbitkan.');
      await _load();
    }
  }

  /// Mengembalikan pesan galat, atau null bila berhasil.
  Future<String?> _publish(_Draft d) async {
    final uid = _db.auth.currentUser!.id;
    final postId = _uuid();
    var ok = 0;
    String? last;
    for (final f in d.photos) {
      if (f.size > _maxBytes) {
        last = '${f.name} lebih dari 10 MB';
        continue;
      }
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$uid/${DateTime.now().microsecondsSinceEpoch}_$safe';
      try {
        await uploadPicked(_db, _bucket, path, f);
        await _db.from('gallery_photos').insert({
          'post_id': postId,
          'title': d.title,
          'body': d.body.isEmpty ? null : d.body,
          'album': d.album,
          'file_path': path,
          'file_name': f.name,
          'size_bytes': f.size,
          'uploaded_by': Access.instance.memberId,
          if (d.web) 'is_public': true,
        });
        ok++;
      } catch (e) {
        last = _why(e);
        try {
          // Hanya berhasil untuk berkas yatim milik sendiri (lihat sql/21_news_admin.sql).
          await _db.storage.from(_bucket).remove([path]);
        } catch (_) {}
      }
    }
    if (ok == 0) {
      return 'Gagal mengunggah: ${last ?? 'tidak diketahui'}. Pastikan sql/18_gallery.sql, 20_gallery_news.sql, dan 21_news_admin.sql sudah dijalankan.';
    }
    if (ok < d.photos.length) _snack('$ok dari ${d.photos.length} foto terunggah (${last ?? 'sebagian gagal'}).');
    return null;
  }

  /// Hanya admin (ditegakkan RLS). Mengembalikan true bila terhapus.
  Future<bool> _deletePost(NewsPost p) async {
    try {
      await NewsRepository.delete(p);
      _snack('Berita dihapus.');
      await _load();
      return true;
    } on NewsForbiddenException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal menghapus berita.');
    }
    return false;
  }

  Future<void> _confirmAndDelete(NewsPost p) async {
    if (await confirmDeleteNews(context, p)) await _deletePost(p);
  }

  void _open(NewsPost p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NewsDetailPage(
        post: p,
        urls: _urls,
        onDelete: _isAdmin ? () => _deletePost(p) : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Scaffold(
      appBar: AppBar(title: const Text('Berita & Dokumentasi')),
      floatingActionButton: NavClearance(
        child: FloatingActionButton.extended(
          onPressed: _compose,
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Tulis berita'),
        ),
      ),
      body: PageGlow(accent: AppColors.rose, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: ScreenHero(
            title: 'Berita',
            subtitle: _isAdmin ? 'Kabar kegiatan dan perkara. Anda admin: dapat menghapus berita.' : 'Kabar kegiatan dan perkara, lengkap dengan foto',
            icon: Icons.newspaper_rounded,
            accent: AppColors.rose,
            chips: [(Icons.article_outlined, '${_all.length} berita'), (Icons.image_outlined, '${_feed?.photoCount ?? 0} foto')],
          ),
        ),
        if (_albums.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final a in [null, ..._albums])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: a == null ? null : Icon(newsAlbumIcon(a), size: 16, color: _album == a ? Colors.white : newsAlbumColor(a)),
                      label: Text(a ?? 'Semua'),
                      selected: _album == a,
                      selectedColor: a == null ? AppColors.navy : newsAlbumColor(a),
                      labelStyle: TextStyle(color: _album == a ? Colors.white : null, fontWeight: FontWeight.w700),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _album = a),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: _body(shown)),
      ])),
    );
  }

  Widget _body(List<NewsPost> shown) {
    if (_loading) return const SkeletonList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (shown.isEmpty) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const EmptyState(message: 'Belum ada berita.\nTulis kabar kegiatan pertama, lengkap dengan foto.', icon: Icons.newspaper_rounded),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: PrimaryButton(label: 'Tulis berita pertama', icon: Icons.edit_note_rounded, onPressed: _compose),
        ),
        const SizedBox(height: 96),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => Reveal(
          index: i % 8,
          dy: 12,
          child: i == 0 ? _featured(shown[i]) : _card(shown[i]),
        ),
      ),
    );
  }

  Widget _featured(NewsPost p) {
    final accent = newsAlbumColor(p.album);
    return Pressable(
      onTap: () => _open(p),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.26), blurRadius: 26, offset: const Offset(0, 14))],
        ),
        child: AspectRatio(
          aspectRatio: 16 / 11.5,
          child: Stack(fit: StackFit.expand, children: [
            NewsCover(url: _urls[p.paths.first], cacheWidth: 900),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Colors.transparent, Color(0xF008142E)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              right: _isAdmin ? 64 : 16,
              child: Row(children: [
                Flexible(child: NewsPill(p.album, color: accent, icon: newsAlbumIcon(p.album))),
                if (p.isFresh) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(12)),
                    child: const Text('BARU',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  ),
                ],
              ]),
            ),
            if (_isAdmin)
              Positioned(
                right: 12,
                top: 12,
                child: GlassCircleButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Hapus berita (admin)',
                  onTap: () => _confirmAndDelete(p),
                ),
              ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xCCFFFFFF)),
                  const SizedBox(width: 4),
                  Text(timeAgoId(p.date),
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  const Icon(Icons.photo_library_rounded, size: 14, color: Color(0xCCFFFFFF)),
                  const SizedBox(width: 4),
                  Text('${p.rows.length}',
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _card(NewsPost p) {
    final sc = Theme.of(context).colorScheme;
    final accent = newsAlbumColor(p.album);
    final excerpt = p.body.replaceAll(RegExp(r'\s+'), ' ');
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      onTap: () => _open(p),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(fit: StackFit.expand, children: [
              NewsCover(url: _urls[p.paths.first], cacheWidth: 300),
              if (p.isFresh)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text('BARU', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(newsAlbumIcon(p.album), size: 14, color: accent),
              const SizedBox(width: 5),
              Flexible(
                child: Text(p.album.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: accent)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
            if (excerpt.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(excerpt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, height: 1.35, color: sc.onSurfaceVariant)),
            ],
            const SizedBox(height: 8),
            Text('${timeAgoId(p.date)}  •  ${p.rows.length} foto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sc.onSurfaceVariant)),
          ]),
        ),
        if (_isAdmin)
          IconButton(
            tooltip: 'Hapus berita (admin)',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
            onPressed: () => _confirmAndDelete(p),
          ),
      ]),
    );
  }
}

/// Layar tulis berita: foto (galeri/kamera), judul, isi tulisan, album. Tombol terbit di zona jempol.
class _ComposePage extends StatefulWidget {
  const _ComposePage({required this.albums, required this.initialAlbum, required this.onPublish, this.canWeb = false});
  final List<String> albums;
  final bool canWeb;
  final String initialAlbum;
  final Future<String?> Function(_Draft) onPublish;
  @override
  State<_ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<_ComposePage> {
  static const _maxPhotos = 10;
  final _photos = <PlatformFile>[];
  late final _title = TextEditingController();
  late final _body = TextEditingController();
  late final _album = TextEditingController(text: widget.initialAlbum);
  bool _sending = false;
  bool _web = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _album.dispose();
    super.dispose();
  }

  Future<void> _add({required bool camera}) async {
    try {
      final got = await pickPhotos(camera: camera);
      if (got.isEmpty || !mounted) return;
      setState(() {
        _photos.addAll(got);
        if (_photos.length > _maxPhotos) {
          _photos.removeRange(_maxPhotos, _photos.length);
          _error = 'Maksimal $_maxPhotos foto per berita.';
        } else {
          _error = null;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Tidak bisa membuka ${camera ? 'kamera' : 'galeri foto'}: $e');
    }
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    if (_photos.isEmpty) {
      setState(() => _error = 'Tambahkan minimal satu foto.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Judul berita wajib diisi.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final album = _album.text.trim().isEmpty ? 'Umum' : _album.text.trim();
    final err = await widget.onPublish(_Draft(List.of(_photos), title, _body.text.trim(), album, web: widget.canWeb && _web));
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _sending = false;
        _error = err;
      });
    }
  }

  Widget _thumb(PlatformFile f) {
    if (kIsWeb || f.path == null) {
      return f.bytes == null ? const SizedBox() : Image.memory(f.bytes!, fit: BoxFit.cover, cacheWidth: 240);
    }
    return Image.file(File(f.path!), fit: BoxFit.cover, cacheWidth: 240);
  }

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tulis berita'), leading: const CloseButton()),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Text('Foto (${_photos.length}/$_maxPhotos)', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (_photos.isEmpty)
          Container(
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.navy.withValues(alpha: 0.12)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32, color: sc.onSurfaceVariant),
              const SizedBox(height: 6),
              Text('Belum ada foto', style: TextStyle(color: sc.onSurfaceVariant)),
            ]),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 96, height: 96, child: _thumb(_photos[i]))),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: _sending ? null : () => setState(() => _photos.removeAt(i)),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Color(0xB3000000), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
                if (i == 0)
                  Positioned(left: 6, bottom: 6, child: NewsPill('Sampul', color: AppColors.red)),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _sending || _photos.length >= _maxPhotos ? null : () => _add(camera: false),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeri'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sending || _photos.length >= _maxPhotos ? null : () => _add(camera: true),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 24),
        TextField(
          controller: _title,
          enabled: !_sending,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Judul berita', prefixIcon: Icon(Icons.title_rounded)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          enabled: !_sending,
          minLines: 6,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Isi tulisan',
            alignLabelWithHint: true,
            helperText: 'Ceritakan apa yang terjadi, siapa yang terlibat, kapan dan di mana.',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _album,
          enabled: !_sending,
          decoration: const InputDecoration(labelText: 'Album / kategori', prefixIcon: Icon(Icons.folder_outlined)),
        ),
        if (widget.albums.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final a in widget.albums) ActionChip(label: Text(a), onPressed: _sending ? null : () => setState(() => _album.text = a)),
          ]),
        ],
        if (widget.canWeb) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _web,
            onChanged: _sending ? null : (v) => setState(() => _web = v),
            secondary: const Icon(Icons.public_rounded),
            title: const Text('Terbitkan juga di situs resmi', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Berita dan fotonya tampil untuk umum di halaman Berita situs PERKAPI.'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline, size: 20, color: AppColors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, height: 1.35))),
            ]),
          ),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_sending) ...[
              const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(4)), child: LinearProgressIndicator(minHeight: 4)),
              const SizedBox(height: 8),
              Text('Mengunggah ${_photos.length} foto, mohon tunggu...', style: TextStyle(fontSize: 12, color: sc.onSurfaceVariant)),
              const SizedBox(height: 8),
            ],
            PrimaryButton(
              label: _sending ? 'Menerbitkan...' : 'Terbitkan berita',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: _sending ? null : _send,
            ),
          ]),
        ),
      ),
    );
  }
}
