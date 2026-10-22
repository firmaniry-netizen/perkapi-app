import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Surat otomatis perkara. Teks adalah DRAF UMUM: periksa dan sesuaikan dengan penetapan pengadilan
/// serta kebiasaan kantor sebelum dikirim. Font bawaan PDF hanya Latin-1, jadi tanda baca khusus disederhanakan.
enum LetterKind { undangan, pemberitahuan, beritaAcara }

extension LetterKindInfo on LetterKind {
  String get title => switch (this) {
        LetterKind.undangan => 'Undangan Rapat Kreditur',
        LetterKind.pemberitahuan => 'Pemberitahuan dan Permintaan Pengajuan Tagihan',
        LetterKind.beritaAcara => 'Berita Acara Rapat Kreditur',
      };
  String get fileName => switch (this) {
        LetterKind.undangan => 'Undangan_Rapat_Kreditur',
        LetterKind.pemberitahuan => 'Pemberitahuan_Kreditur',
        LetterKind.beritaAcara => 'Berita_Acara_Rapat',
      };
  bool get hasRecipients => this != LetterKind.beritaAcara;
}

typedef Recipient = ({String name, String address});

class LetterData {
  LetterData({
    required this.kind,
    required this.caseNumber,
    required this.caseTitle,
    required this.caseType,
    required this.court,
    required this.debtorName,
    required this.officerName,
    required this.officerAddress,
    required this.city,
    required this.letterDate,
    required this.letterNumber,
    this.officerAhu = '',
    this.recipients = const [],
    this.meetingAt,
    this.place = '',
    this.agenda = '',
    this.deadline,
    this.attendees = '',
    this.outcome = '',
    this.judgeName = '',
  });

  final LetterKind kind;
  final String caseNumber, caseTitle, caseType, court, debtorName;
  final String officerName, officerAddress, officerAhu, city, letterNumber;
  final DateTime letterDate;
  final List<Recipient> recipients; // kosong = "Para Kreditur"
  final DateTime? meetingAt, deadline;
  final String place, agenda, attendees, outcome, judgeName;

  bool get isPkpu => caseType.toUpperCase().contains('PKPU');
  String get role => isPkpu ? 'Pengurus' : 'Kurator';
  String get caseKind => isPkpu ? 'Penundaan Kewajiban Pembayaran Utang (PKPU)' : 'Kepailitan';
}

const _bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String tglPanjang(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';
String hariTgl(DateTime d) => '${_hari[d.weekday - 1]}, ${tglPanjang(d)}';
String jam(DateTime d) => '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')} WIB';

String _t(String s) {
  const map = {
    '\u2018': "'", '\u2019': "'", '\u201C': '"', '\u201D': '"', '\u2013': '-', '\u2014': '-',
    '\u2026': '...', '\u2022': '-', '\u00A0': ' ',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    if (map.containsKey(ch)) {
      b.write(map[ch]);
    } else if (r > 255) {
      b.write('?');
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}

pw.TextStyle _st({double size = 11, bool bold = false}) =>
    pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, lineSpacing: 3);

pw.Widget _p(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.justify, double size = 11}) =>
    pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8), child: pw.Text(_t(text), textAlign: align, style: _st(size: size, bold: bold)));

pw.Widget _row(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 92, child: pw.Text(_t(label), style: _st())),
        pw.Text(': ', style: _st()),
        pw.Expanded(child: pw.Text(_t(value), style: _st())),
      ]),
    );

pw.Widget _kop(LetterData d) => pw.Column(children: [
      pw.Center(child: pw.Text(_t(d.officerName.toUpperCase()), style: _st(size: 14, bold: true))),
      pw.Center(child: pw.Text(_t('${d.role} dalam ${d.caseKind}'), style: _st(size: 10))),
      if (d.officerAddress.trim().isNotEmpty)
        pw.Center(child: pw.Text(_t(d.officerAddress.replaceAll(RegExp(r'\s*\n\s*'), ', ')), style: _st(size: 9), textAlign: pw.TextAlign.center)),
      pw.SizedBox(height: 6),
      pw.Divider(thickness: 1.4, height: 6),
      pw.SizedBox(height: 10),
    ]);

pw.Widget _signature(LetterData d) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_t('${d.city}, ${tglPanjang(d.letterDate)}'), style: _st()),
          pw.Text(_t('${d.role} ${d.debtorName}'), style: _st()),
          pw.SizedBox(height: 62),
          pw.Text(_t(d.officerName), style: _st(bold: true)),
          if (d.officerAhu.trim().isNotEmpty)
            pw.Text(_t('Terdaftar di Kementerian Hukum, Surat Bukti Pendaftaran No. ${d.officerAhu}'), style: _st(size: 8.5)),
        ]),
      ),
    );

pw.Widget _draftFooter() => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Draf dibuat dengan PERKAPI - periksa isi sebelum dikirim', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
    );

List<pw.Widget> _undangan(LetterData d, Recipient? to) {
  final m = d.meetingAt;
  return [
    _kop(d),
    _row('Nomor', d.letterNumber.isEmpty ? '-' : d.letterNumber),
    _row('Lampiran', '-'),
    _row('Perihal', 'Undangan Rapat Kreditur'),
    pw.SizedBox(height: 10),
    _p('Yth.\n${to?.name ?? 'Para Kreditur'}${(to?.address ?? '').isNotEmpty ? '\n${to!.address}' : ''}', align: pw.TextAlign.left),
    _p('Dengan hormat,'),
    _p('Sehubungan dengan perkara ${d.caseKind} ${d.caseTitle} pada ${d.court.isEmpty ? 'Pengadilan' : d.court} Nomor ${d.caseNumber} '
        'terhadap ${d.debtorName}, bersama ini kami selaku ${d.role} mengundang Bapak/Ibu/Saudara selaku Kreditur untuk menghadiri Rapat Kreditur yang akan diselenggarakan pada:'),
    pw.Padding(
      padding: const pw.EdgeInsets.only(left: 18, bottom: 8),
      child: pw.Column(children: [
        _row('Hari/Tanggal', m == null ? '-' : hariTgl(m)),
        _row('Waktu', m == null ? '-' : jam(m)),
        _row('Tempat', d.place.isEmpty ? '-' : d.place),
        _row('Acara', d.agenda.isEmpty ? '-' : d.agenda),
      ]),
    ),
    _p('Mengingat pentingnya acara tersebut, kami mohon Bapak/Ibu/Saudara hadir tepat waktu dengan membawa identitas diri dan dokumen yang berkaitan dengan tagihan. '
        'Apabila diwakilkan, mohon membawa surat kuasa yang sah.'),
    _p('Demikian disampaikan. Atas perhatian dan kerja sama Bapak/Ibu/Saudara, kami ucapkan terima kasih.'),
    pw.SizedBox(height: 14),
    _signature(d),
    pw.SizedBox(height: 10),
    _draftFooter(),
  ];
}

List<pw.Widget> _pemberitahuan(LetterData d, Recipient? to) => [
      _kop(d),
      _row('Nomor', d.letterNumber.isEmpty ? '-' : d.letterNumber),
      _row('Lampiran', '-'),
      _row('Perihal', 'Pemberitahuan dan Permintaan Pengajuan Tagihan'),
      pw.SizedBox(height: 10),
      _p('Yth.\n${to?.name ?? 'Para Kreditur'}${(to?.address ?? '').isNotEmpty ? '\n${to!.address}' : ''}', align: pw.TextAlign.left),
      _p('Dengan hormat,'),
      _p('Kami memberitahukan bahwa ${d.court.isEmpty ? 'Pengadilan' : d.court} telah memeriksa perkara ${d.caseKind} Nomor ${d.caseNumber} '
          '(${d.caseTitle}) terhadap ${d.debtorName}, dan kami telah ditunjuk selaku ${d.role} dalam perkara tersebut.'),
      _p('Sehubungan dengan itu, kami mohon Bapak/Ibu/Saudara selaku Kreditur mengajukan tagihan secara tertulis beserta dokumen pendukung '
          '(rincian tagihan, bukti hubungan hukum/perjanjian, dan identitas) '
          '${d.deadline == null ? 'dalam waktu yang ditetapkan' : 'paling lambat ${hariTgl(d.deadline!)}'} '
          'kepada kami${d.place.isEmpty ? '' : ' di ${d.place}'}. '
          'Mohon pengajuan dilakukan tepat waktu agar tagihan dapat diproses pada tahap pencocokan piutang.'),
      _p('Demikian disampaikan. Atas perhatian dan kerja sama Bapak/Ibu/Saudara, kami ucapkan terima kasih.'),
      pw.SizedBox(height: 14),
      _signature(d),
      pw.SizedBox(height: 10),
      _draftFooter(),
    ];

List<pw.Widget> _beritaAcara(LetterData d) {
  final m = d.meetingAt;
  return [
    _kop(d),
    pw.Center(child: pw.Text('BERITA ACARA RAPAT KREDITUR', style: _st(size: 13, bold: true))),
    pw.Center(child: pw.Text(_t('Perkara ${d.caseKind} Nomor ${d.caseNumber}'), style: _st())),
    pw.SizedBox(height: 12),
    _p('Pada hari ini, ${m == null ? '-' : hariTgl(m)}, pukul ${m == null ? '-' : jam(m)}, bertempat di ${d.place.isEmpty ? '-' : d.place}, '
        'telah diselenggarakan Rapat Kreditur dalam perkara ${d.caseKind} ${d.caseTitle} pada ${d.court.isEmpty ? 'Pengadilan' : d.court} '
        'Nomor ${d.caseNumber} terhadap ${d.debtorName}'
        '${d.judgeName.isEmpty ? '' : ', dengan Hakim Pengawas ${d.judgeName}'}.'),
    _p('Rapat dipimpin dan dihadiri oleh ${d.officerName} selaku ${d.role}${d.attendees.isEmpty ? '' : ', serta dihadiri oleh: ${d.attendees}'}. '
        'Daftar hadir terlampir dan menjadi bagian yang tidak terpisahkan dari berita acara ini.'),
    _p('Acara rapat:', bold: true, align: pw.TextAlign.left),
    _p(d.agenda.isEmpty ? '-' : d.agenda),
    _p('Jalannya rapat dan hasil/keputusan:', bold: true, align: pw.TextAlign.left),
    _p(d.outcome.isEmpty ? '-' : d.outcome),
    _p('Demikian berita acara ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.'),
    pw.SizedBox(height: 14),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(
        width: 200,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Hakim Pengawas', style: _st()),
          pw.SizedBox(height: 62),
          pw.Text(_t(d.judgeName.isEmpty ? '(.............................)' : d.judgeName), style: _st(bold: true)),
        ]),
      ),
      _signature(d),
    ]),
    pw.SizedBox(height: 10),
    _draftFooter(),
  ];
}

/// Membuat PDF. Surat dengan penerima dibuat satu halaman per penerima.
Future<List<int>> buildLetterPdf(LetterData d) async {
  final doc = pw.Document(title: d.kind.title, author: d.officerName);
  pw.Page page(List<pw.Widget> children) => pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 44, 56, 44),
        build: (_) => children,
      );
  switch (d.kind) {
    case LetterKind.beritaAcara:
      doc.addPage(page(_beritaAcara(d)));
    case LetterKind.undangan:
    case LetterKind.pemberitahuan:
      final targets = d.recipients.isEmpty ? <Recipient?>[null] : <Recipient?>[...d.recipients];
      for (final to in targets) {
        doc.addPage(page(d.kind == LetterKind.undangan ? _undangan(d, to) : _pemberitahuan(d, to)));
      }
  }
  return doc.save();
}
