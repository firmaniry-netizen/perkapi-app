import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/services/supabase_service.dart';
import '../../shared/models/modules.dart';

/// Ekspor CSV (dibuka di Excel) dan PDF. Isian bertipe lookup diekspor apa adanya (berupa ID).
class ExportService {
  static String _esc(Object? v) {
    final s = v == null ? '' : '$v';
    return (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _shareFile(String name, String ext, List<int> bytes, String mime) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${name}_${_stamp()}.$ext');
    await f.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(f.path, mimeType: mime)], subject: 'PERKAPI $name');
  }

  /// Membagikan berkas apa pun (mis. PDF surat) lewat lembar bagikan sistem.
  static Future<void> shareBytes(String name, String ext, List<int> bytes, String mime) =>
      _shareFile(name, ext, bytes, mime);

  static Future<void> shareCsv(String name, List<String> header, List<List<Object?>> rows) async {
    final sb = StringBuffer('\uFEFF')..writeln(header.map(_esc).join(','));
    for (final r in rows) {
      sb.writeln(r.map(_esc).join(','));
    }
    await _shareFile(name, 'csv', utf8.encode(sb.toString()), 'text/csv');
  }

  // Font bawaan PDF hanya Latin-1: karakter lain diganti agar tidak error.
  static String _cell(Object? v) {
    final s = (v == null ? '' : '$v').replaceAll(RegExp(r'[\r\n]+'), ' ');
    final safe = String.fromCharCodes(s.runes.map((c) => c > 255 ? 63 : c));
    return safe.length > 120 ? '${safe.substring(0, 117)}...' : safe;
  }

  static Future<void> sharePdf(String name, String title, List<String> header, List<List<Object?>> rows) async {
    final doc = pw.Document();
    final landscape = header.length > 5;
    doc.addPage(pw.MultiPage(
      pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (c) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(_cell(title), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('PERKAPI - ${_stamp()} - Halaman ${c.pageNumber}/${c.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (c) => [
        pw.TableHelper.fromTextArray(
          headers: header.map(_cell).toList(),
          data: [for (final r in rows) [for (final v in r) _cell(v)]],
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),
      ],
    ));
    await _shareFile(name, 'pdf', await doc.save(), 'application/pdf');
  }

  static Future<int> exportModule(String moduleId, {bool pdf = false}) async {
    final m = modules[moduleId]!;
    final res = await SupabaseService.client.from(m.table).select().limit(5000);
    final data = List<Map<String, dynamic>>.from(res as List);
    if (pdf) {
      final fields = m.fields.take(6).toList();
      await sharePdf(m.id, m.title, fields.map((f) => f.label).toList(), [for (final r in data) [for (final f in fields) r[f.key]]]);
    } else {
      final keys = ['id', ...m.fields.map((f) => f.key)];
      await shareCsv(m.id, ['ID', ...m.fields.map((f) => f.label)], [for (final r in data) [for (final k in keys) r[k]]]);
    }
    return data.length;
  }
}
