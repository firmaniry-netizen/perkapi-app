import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/access_service.dart';
import '../../core/services/offline_cache.dart';
import '../../core/services/supabase_service.dart';
import '../models/modules.dart';

class DataException implements Exception {
  DataException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DataRepository {
  static SupabaseClient get _db => SupabaseService.client;

  static String _sanitize(String q) => q.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  /// Data milik pribadi (catatan, dll.) butuh baris anggota. Tanpa itu, filter `member_id = ''`
  /// ditolak Postgres (uuid tidak valid) dan tampil sebagai galat generik yang menyesatkan.
  static void _needMember() {
    if (Access.instance.memberId == null) {
      throw DataException(
          'Akun Anda belum terhubung ke data anggota, sehingga data pribadi tidak dapat dimuat. Hubungi pengurus PERKAPI.');
    }
  }

  static DataException _wrap(Object e) {
    if (e is PostgrestException) {
      debugPrint('[DataRepository] ${e.code} | ${e.message} | ${e.details} | ${e.hint}');
      if (e.code == '42501') {
        return DataException('Anda tidak memiliki izin untuk tindakan ini.');
      }
      if (e.code == '42703' || e.code == '42P01') {
        return DataException('Struktur database belum sesuai. Jalankan skrip SQL pada folder sql/.');
      }
      if (e.code == '23505') return DataException('Data sudah ada (duplikat).');
      return DataException('Terjadi kesalahan saat memproses data. (kode ${e.code ?? 'tidak diketahui'})');
    }
    return DataException('Tidak dapat terhubung. Periksa koneksi internet Anda.');
  }

  static Future<List<Map<String, dynamic>>> list(
    ModuleDef m, {
    String q = '',
    int offset = 0,
    int limit = 20,
  }) async {
    if (m.ownOnly && m.ownerKey != null) _needMember();
    try {
      var qb = _db.from(m.table).select();
      for (final e in m.filter.entries) {
        qb = qb.eq(e.key, e.value);
      }
      if (m.ownOnly && m.ownerKey != null) {
        qb = qb.eq(m.ownerKey!, Access.instance.memberId ?? '');
      }
      final s = _sanitize(q);
      if (s.isNotEmpty && m.searchKeys.isNotEmpty) {
        qb = qb.or(m.searchKeys.map((k) => '$k.ilike.%$s%').join(','));
      }
      final rows = await qb.order(m.orderBy, ascending: false).range(offset, offset + limit - 1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (m.offlineCache && offset == 0 && s.isEmpty) {
        OfflineCache.offline.value = false;
        await OfflineCache.save(_cacheKey(m), list);
      }
      return list;
    } catch (e) {
      // Gangguan jaringan (bukan penolakan server): tampilkan cache terakhir bila ada.
      if (e is! PostgrestException && m.offlineCache && offset == 0 && _sanitize(q).isEmpty) {
        final cached = await OfflineCache.load(_cacheKey(m));
        if (cached != null) {
          OfflineCache.offline.value = true;
          return cached;
        }
      }
      throw _wrap(e);
    }
  }

  static String _cacheKey(ModuleDef m) => '${Access.instance.memberId ?? 'anon'}:${m.id}';

  static Future<Map<String, dynamic>?> get(ModuleDef m, String id) async {
    try {
      return await _db.from(m.table).select().eq('id', id).maybeSingle();
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> insert(ModuleDef m, Map<String, dynamic> data) async {
    if (m.ownOnly && m.ownerKey != null) _needMember();
    try {
      final payload = {...data};
      if (m.ownerKey != null) payload[m.ownerKey!] = Access.instance.memberId;
      await _db.from(m.table).insert(payload);
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> update(ModuleDef m, String id, Map<String, dynamic> data) async {
    try {
      await _db.from(m.table).update(data).eq('id', id);
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<void> delete(ModuleDef m, String id) async {
    try {
      await _db.from(m.table).delete().eq('id', id);
    } catch (e) {
      throw _wrap(e);
    }
  }

  static Future<int> count(String table, {Map<String, Object> eq = const {}}) async {
    try {
      var qb = _db.from(table).select('id');
      for (final e in eq.entries) {
        qb = qb.eq(e.key, e.value);
      }
      final res = await qb.count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> lookup(String table, String label) async {
    try {
      final rows = await _db.from(table).select('id,$label').order(label).limit(200);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  static Future<void> markAllNotificationsRead() async {
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('member_id', Access.instance.memberId ?? '')
          .eq('is_read', false);
    } catch (e) {
      throw _wrap(e);
    }
  }
}
