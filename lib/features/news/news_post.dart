import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/env.dart';
import '../../core/services/supabase_service.dart';

/// Satu berita = judul + isi tulisan + beberapa foto (baris gallery_photos dengan post_id sama).
/// Foto lama tanpa post_id tampil sebagai berita satu foto.
class NewsPost {
  NewsPost(this.id, this.rows);
  final String id;
  final List<Map<String, dynamic>> rows; // urut dari foto pertama
  Map<String, dynamic> get first => rows.first;
  String get album => '${first['album'] ?? 'Umum'}';
  String get title {
    final t = '${first['title'] ?? ''}'.trim();
    if (t.isNotEmpty) return t;
    final c = '${first['caption'] ?? ''}'.trim();
    return c.isNotEmpty ? c : 'Dokumentasi $album';
  }

  String get body => '${first['body'] ?? ''}'.trim();

  /// Berita dari situs (diterbitkan lewat panel admin situs). Dikelola di situs, bukan di aplikasi.
  bool get isSite => first['source'] == 'site';
  DateTime? get date => DateTime.tryParse('${first['created_at'] ?? ''}')?.toLocal();
  List<String> get paths => [for (final r in rows) r['file_path'] as String];
  bool get isFresh => date != null && DateTime.now().difference(date!).inHours < 48;
}

class NewsFeed {
  NewsFeed(this.posts, this.urls, this.photoCount);
  final List<NewsPost> posts;
  final Map<String, String> urls; // file_path -> signed url
  final int photoCount;
}

class NewsForbiddenException implements Exception {
  const NewsForbiddenException([this.message = 'Hanya admin yang dapat menghapus berita dan foto.']);
  final String message;
  @override
  String toString() => message;
}

class NewsRepository {
  NewsRepository._();
  static const bucket = 'gallery';
  static SupabaseClient get _db => SupabaseService.client;

  static List<NewsPost> group(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      (groups['${r['post_id'] ?? r['id']}'] ??= []).add(r);
    }
    return [
      for (final e in groups.entries)
        NewsPost(e.key, e.value..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'))),
    ];
  }

  /// [postLimit] membatasi jumlah berita terbaru (dashboard). [coversOnly] hanya menandatangani foto sampul.
  /// Berita aplikasi (gallery_photos) digabung dengan berita situs (site_news, lewat RPC publik yang sama
  /// dengan situs) sehingga isi aplikasi dan situs selalu sama. Berita aplikasi yang dicentang
  /// "Tampilkan di situs" sebaliknya muncul di situs.
  static Future<NewsFeed> load({int? postLimit, bool coversOnly = false}) async {
    // keduanya dimulai bersamaan, lalu ditunggu
    final siteF = _sitePosts(postLimit ?? 60);
    final rows = List<Map<String, dynamic>>.from(
        await _db.from('gallery_photos').select().order('created_at', ascending: false).limit(postLimit == null ? 300 : 120));
    final sitePosts = await siteF;
    final appPosts = group(rows);
    // berita aplikasi yang juga tayang di situs muncul sekali saja (versi aplikasi, lengkap dengan semua foto)
    var posts = <NewsPost>[...appPosts, ...sitePosts]
      ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    if (postLimit != null && posts.length > postLimit) posts = posts.sublist(0, postLimit);
    final paths = [
      for (final p in posts) ...(coversOnly ? [p.paths.first] : p.paths),
    ];
    final urls = await signUrls(paths);
    return NewsFeed(posts, urls, rows.length);
  }

  /// Berita dari situs: daftar lewat `public_news`, isi lengkap lewat `public_news_item`.
  /// Gagal memuat (mis. offline) tidak menggagalkan berita aplikasi.
  static Future<List<NewsPost>> _sitePosts(int limit) async {
    try {
      final list = List<Map<String, dynamic>>.from(await _db.rpc('public_news', params: {'p_limit': limit}) as List);
      final site = list.where((r) => '${r['id']}'.startsWith('s:')).toList();
      final full = await Future.wait(site.map((r) async {
        try {
          final d = List<Map<String, dynamic>>.from(await _db.rpc('public_news_item', params: {'p_id': r['id']}) as List);
          return d.isEmpty ? null : d.first;
        } catch (_) {
          return null;
        }
      }));
      return [
        for (var i = 0; i < site.length; i++)
          NewsPost('${site[i]['id']}', [
            {
              'id': site[i]['id'],
              'title': site[i]['title'],
              'body': full[i]?['body'] ?? site[i]['excerpt'],
              'created_at': site[i]['created_at'],
              'album': site[i]['category'] ?? 'Berita',
              'file_path': sitePhotoUrl(site[i]['photo_path'] as String?) ?? 'site-nophoto:${site[i]['id']}',
              'source': 'site',
            }
          ]),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Alamat foto berita situs, sama aturannya dengan situs (js/site.js photoUrl):
  /// URL penuh apa adanya; "img/..." = berkas di hosting situs; selain itu = bucket publik news-photos.
  static String? sitePhotoUrl(String? p) {
    if (p == null || p.trim().isEmpty || p.startsWith('gallery:')) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (p.startsWith('img/') || p.startsWith('/')) return '${Env.siteUrl}/${p.replaceFirst(RegExp(r'^/+'), '')}';
    return '${Env.supabaseUrl}/storage/v1/object/public/news-photos/${Uri.encodeFull(p)}';
  }

  /// Tautan bertanda tangan (1 jam) untuk daftar path di bucket privat.
  /// Foto berita situs sudah berupa URL publik (dipakai apa adanya); berita tanpa foto dilewati.
  static Future<Map<String, String>> signUrls(List<String> paths) async {
    final urls = <String, String>{};
    final private = <String>[];
    for (final p in paths) {
      if (p.startsWith('http://') || p.startsWith('https://')) {
        urls[p] = p;
      } else if (!p.startsWith('site-nophoto:')) {
        private.add(p);
      }
    }
    if (private.isEmpty) return urls;
    final signed = await _db.storage.from(bucket).createSignedUrls(private, 3600);
    for (var i = 0; i < signed.length && i < private.length; i++) {
      urls[private[i]] = signed[i].signedUrl;
    }
    return urls;
  }

  /// Hapus berita beserta semua fotonya. Hanya admin (RLS is_admin()).
  /// Baris dihapus lebih dulu; bila database menolak (bukan admin) tidak ada berkas yang disentuh.
  static Future<void> delete(NewsPost p) async {
    if (p.isSite) throw const NewsForbiddenException('Berita ini diterbitkan dari situs. Ubah atau hapus lewat panel admin situs.');
    final ids = [for (final r in p.rows) r['id']];
    final gone = await _db.from('gallery_photos').delete().inFilter('id', ids).select('id,file_path');
    if (gone.isEmpty) throw const NewsForbiddenException();
    final paths = [for (final r in gone) r['file_path'] as String];
    try {
      await _db.storage.from(bucket).remove(paths);
    } catch (_) {
      // Baris sudah terhapus; berkas yatim tidak terlihat pengguna.
    }
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String formatTanggal(DateTime? d) => d == null ? '' : '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "Baru saja", "3 jam lalu", "2 hari lalu", lalu tanggal penuh setelah seminggu.
String timeAgoId(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return formatTanggal(d);
}

/// Warna tetap per album/kategori agar berita mudah dikenali sekilas.
Color newsAlbumColor(String album) {
  const palette = <Color>[
    AppColors.rose,
    AppColors.navyAction,
    AppColors.teal,
    AppColors.violet,
    AppColors.emerald,
    Color(0xFFB45309),
    Color(0xFFC2410C),
  ];
  var h = 0;
  for (final c in album.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

IconData newsAlbumIcon(String album) {
  final k = album.toLowerCase();
  bool has(List<String> w) => w.any(k.contains);
  if (has(['perkara', 'sidang', 'putusan', 'pengadilan'])) return CupertinoIcons.hammer_fill;
  if (has(['rapat', 'musyawarah', 'rakor'])) return CupertinoIcons.person_3_fill;
  if (has(['pelatihan', 'diklat', 'seminar', 'workshop'])) return CupertinoIcons.book_fill;
  if (has(['sosial', 'bakti'])) return CupertinoIcons.heart_circle;
  if (has(['pengumuman', 'info'])) return CupertinoIcons.speaker_2_fill;
  return CupertinoIcons.photo_on_rectangle;
}
