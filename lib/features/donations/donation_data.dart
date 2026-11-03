import 'package:file_picker/file_picker.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/upload_helper.dart';

/// Kategori kampanye (sama dengan CHECK di sql/45_donasi.sql).
const donationCategories = ['Event', 'Sosial', 'Bencana', 'Pendidikan', 'Organisasi', 'Lainnya'];

/// Satu kampanye donasi + ringkasannya (terkumpul, jumlah donatur, menunggu verifikasi).
class Campaign {
  Campaign(this.row, {this.collected = 0, this.donors = 0, this.pending = 0});
  final Map<String, dynamic> row;
  int collected, donors, pending;

  String get id => '${row['id']}';
  String get title => '${row['title'] ?? ''}';
  String get category => '${row['category'] ?? 'Lainnya'}';
  String get description => '${row['description'] ?? ''}';
  int? get target => (row['target_amount'] as num?)?.toInt();
  DateTime? get endsAt => row['ends_at'] == null ? null : DateTime.tryParse('${row['ends_at']}');
  bool get active => row['is_active'] == true;
  String? get coverPath => _s(row['cover_path']);
  String? get qrisPath => _s(row['qris_path']);
  String? get bankName => _s(row['bank_name']);
  String? get accountNumber => _s(row['account_number']);
  String? get accountHolder => _s(row['account_holder']);

  bool get ended {
    final e = endsAt;
    if (e == null) return false;
    final n = DateTime.now();
    return DateTime(e.year, e.month, e.day).isBefore(DateTime(n.year, n.month, n.day));
  }

  bool get open => active && !ended;
  double get progress => (target ?? 0) <= 0 ? 0 : (collected / target!).clamp(0, 1).toDouble();

  /// "12 hari lagi", "Hari terakhir", "Selesai", atau null bila tanpa batas waktu.
  String? get timeLeft {
    final e = endsAt;
    if (e == null) return null;
    final n = DateTime.now();
    final d = DateTime(e.year, e.month, e.day).difference(DateTime(n.year, n.month, n.day)).inDays;
    if (d < 0) return 'Selesai';
    if (d == 0) return 'Hari terakhir';
    return '$d hari lagi';
  }

  static String? _s(dynamic v) => v == null || '$v'.trim().isEmpty ? null : '$v';
}

/// "Rp 1.250.000"
String rupiah(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $b';
}

/// "1,2 jt", "350 rb" untuk label ringkas.
String rupiahShort(num v) {
  if (v >= 1000000000) return 'Rp ${(v / 1000000000).toStringAsFixed(v % 1000000000 == 0 ? 0 : 1).replaceAll('.', ',')} M';
  if (v >= 1000000) return 'Rp ${(v / 1000000).toStringAsFixed(v % 1000000 == 0 ? 0 : 1).replaceAll('.', ',')} jt';
  if (v >= 1000) return 'Rp ${(v / 1000).round()} rb';
  return rupiah(v);
}

class DonationRepo {
  DonationRepo._();
  static final _db = SupabaseService.client;

  static Future<List<Campaign>> campaigns() async {
    final rows = List<Map<String, dynamic>>.from(
        await _db.from('donation_campaigns').select().order('is_active', ascending: false).order('created_at', ascending: false));
    final list = rows.map(Campaign.new).toList();
    await _attachStats(list);
    return list;
  }

  static Future<Campaign?> campaign(String id) async {
    final row = await _db.from('donation_campaigns').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final c = Campaign(Map<String, dynamic>.from(row));
    await _attachStats([c]);
    return c;
  }

  static Future<void> _attachStats(List<Campaign> list) async {
    try {
      final stats = List<Map<String, dynamic>>.from(await _db.rpc('donation_stats') as List);
      final by = {for (final s in stats) '${s['campaign_id']}': s};
      for (final c in list) {
        final s = by[c.id];
        if (s == null) continue;
        c.collected = (s['collected'] as num?)?.toInt() ?? 0;
        c.donors = (s['donors'] as num?)?.toInt() ?? 0;
        c.pending = (s['pending'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
  }

  /// Donatur terverifikasi (nama disamarkan bila anonim).
  static Future<List<Map<String, dynamic>>> donors(String campaignId) async =>
      List<Map<String, dynamic>>.from(await _db.rpc('donation_donors', params: {'p_campaign': campaignId, 'p_limit': 50}) as List);

  /// Donasi milik saya (semua kampanye, atau satu kampanye).
  static Future<List<Map<String, dynamic>>> mine(String memberId, {String? campaignId}) async {
    var q = _db.from('donations').select('*, donation_campaigns(title)').eq('member_id', memberId);
    if (campaignId != null) q = q.eq('campaign_id', campaignId);
    return List<Map<String, dynamic>>.from(await q.order('created_at', ascending: false));
  }

  /// Pengelola: semua donasi satu kampanye (menunggu verifikasi lebih dulu).
  static Future<List<Map<String, dynamic>>> forReview(String campaignId) async {
    final rows = List<Map<String, dynamic>>.from(await _db
        .from('donations')
        .select('*, members!donations_member_id_fkey(full_name)')
        .eq('campaign_id', campaignId)
        .order('created_at', ascending: false));
    rows.sort((a, b) => (a['status'] == 'menunggu' ? 0 : 1).compareTo(b['status'] == 'menunggu' ? 0 : 1));
    return rows;
  }

  static Future<void> donate({
    required String campaignId,
    required String memberId,
    required int amount,
    required bool anonymous,
    String? message,
    PlatformFile? proof,
  }) async {
    String? path;
    if (proof != null && hasSource(proof)) {
      final ext = (proof.extension ?? proof.name.split('.').last).toLowerCase();
      path = '$memberId/${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
      await uploadPicked(_db, 'donasi-bukti', path, proof);
    }
    try {
      await _db.from('donations').insert({
        'campaign_id': campaignId,
        'member_id': memberId,
        'amount': amount,
        'is_anonymous': anonymous,
        if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
        if (path != null) 'proof_path': path,
      });
    } catch (e) {
      if (path != null) {
        try {
          await _db.storage.from('donasi-bukti').remove([path]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static Future<void> cancel(String donationId, String? proofPath) async {
    await _db.from('donations').delete().eq('id', donationId);
    if (proofPath != null) {
      try {
        await _db.storage.from('donasi-bukti').remove([proofPath]);
      } catch (_) {}
    }
  }

  static Future<void> verify(String donationId, bool ok, {String? reason}) =>
      _db.rpc('admin_verify_donation', params: {'p_id': donationId, 'p_ok': ok, 'p_reason': reason});

  static Future<void> save(Map<String, dynamic> data, {String? id}) async {
    if (id == null) {
      await _db.from('donation_campaigns').insert(data);
    } else {
      await _db.from('donation_campaigns').update(data).eq('id', id);
    }
  }

  static Future<void> remove(String id) => _db.from('donation_campaigns').delete().eq('id', id);

  /// Unggah gambar kampanye (sampul/QRIS) dan kembalikan jalurnya.
  static Future<String> uploadPublic(PlatformFile f, String kind) async {
    final ext = (f.extension ?? f.name.split('.').last).toLowerCase();
    final path = '$kind/${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';
    await uploadPicked(_db, 'donasi-publik', path, f);
    return path;
  }

  static final _urlCache = <String, (String, DateTime)>{};

  /// URL bertanda tangan (berlaku 1 jam) untuk gambar di bucket privat.
  static Future<String?> signedUrl(String bucket, String? path) async {
    if (path == null) return null;
    final key = '$bucket/$path';
    final hit = _urlCache[key];
    if (hit != null && DateTime.now().isBefore(hit.$2)) return hit.$1;
    try {
      final u = await _db.storage.from(bucket).createSignedUrl(path, 3600);
      _urlCache[key] = (u, DateTime.now().add(const Duration(minutes: 50)));
      return u;
    } catch (_) {
      return null;
    }
  }
}
