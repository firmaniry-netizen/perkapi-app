import '../../core/services/access_service.dart';
import '../../core/services/supabase_service.dart';

/// Data perkara yang dipakai bersama oleh Linimasa, Tagihan, dan Surat.
class CaseContext {
  CaseContext({
    required this.row,
    required this.debtorName,
    required this.debtorAddress,
    required this.officerName,
    required this.officerAhu,
    required this.creditors,
  });

  final Map<String, dynamic> row;
  final String debtorName, debtorAddress, officerName, officerAhu;
  final List<Map<String, dynamic>> creditors;

  String get id => '${row['id']}';
  String get number => '${row['case_number'] ?? ''}';
  String get title => '${row['title'] ?? ''}';
  String get type => '${row['case_type'] ?? 'Kepailitan'}';
  String get court => '${row['court'] ?? ''}';
  DateTime? get caseDate => parseDate(row['case_date']);

  static Future<CaseContext> load(String caseId) async {
    final db = SupabaseService.client;
    final row = await db.from('cases').select().eq('id', caseId).maybeSingle();
    if (row == null) throw StateError('Perkara tidak ditemukan atau Anda tidak punya akses.');

    var officer = '';
    var ahu = '';
    final assigned = row['assigned_to'];
    if (assigned != null) {
      try {
        final m = await db.from('members').select('full_name,ahu_registration_number').eq('id', assigned).maybeSingle();
        officer = '${m?['full_name'] ?? ''}';
        ahu = '${m?['ahu_registration_number'] ?? ''}';
      } catch (_) {
        // Kolom AHU belum ada (sql/22 belum dijalankan) atau data anggota tidak boleh dibaca.
        try {
          final m = await db.from('members').select('full_name').eq('id', assigned).maybeSingle();
          officer = '${m?['full_name'] ?? ''}';
        } catch (_) {}
      }
    }
    if (officer.isEmpty) officer = Access.instance.name;

    var debtor = '';
    var debtorAddress = '';
    try {
      final d = await db.from('debtors').select('name,address').eq('case_id', caseId).limit(1);
      if (d.isNotEmpty) {
        debtor = '${d.first['name'] ?? ''}';
        debtorAddress = '${d.first['address'] ?? ''}';
      }
    } catch (_) {}

    var creditors = <Map<String, dynamic>>[];
    try {
      creditors = List<Map<String, dynamic>>.from(
          await db.from('creditors').select('id,name,address,creditor_type').eq('case_id', caseId).order('name'));
    } catch (_) {}

    return CaseContext(
      row: Map<String, dynamic>.from(row),
      debtorName: debtor.isEmpty ? '${row['title'] ?? ''}' : debtor,
      debtorAddress: debtorAddress,
      officerName: officer,
      officerAhu: ahu,
      creditors: creditors,
    );
  }
}

DateTime? parseDate(dynamic v) {
  final s = '${v ?? ''}';
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s.length > 10 ? s.substring(0, 10) : s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String isoDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String dmy(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// 1500000 -> "Rp 1.500.000"
String rp(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $b';
}

num numOf(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;

/// Ambil angka rupiah dari teks ketikan ("1.500.000" -> 1500000).
int? parseRupiah(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
