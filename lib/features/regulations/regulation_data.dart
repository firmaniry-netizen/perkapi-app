/// Katalog peraturan untuk Kurator, Pengurus, Kepailitan, dan PKPU.
///
/// Tautan hanya menunjuk ke sumber di internet (portal resmi pemerintah / Mahkamah Konstitusi),
/// bukan salinan yang disimpan di aplikasi. Jadi isi dokumen selalu mengikuti sumbernya.
/// Untuk menambah peraturan: tambahkan satu `Regulation` di daftar [regulations] di bawah.
/// Pastikan tautan sudah dicoba di peramban sebelum build.
enum RegulationKind { uu, permen, putusan, rancangan }

extension RegulationKindLabel on RegulationKind {
  String get label => switch (this) {
        RegulationKind.uu => 'Undang-Undang',
        RegulationKind.permen => 'Peraturan Menteri',
        RegulationKind.putusan => 'Putusan MK',
        RegulationKind.rancangan => 'Peraturan lainnya',
      };
}

class Regulation {
  const Regulation({
    required this.kind,
    required this.number,
    required this.title,
    required this.summary,
    this.pdfUrl,
    this.pageUrl,
    this.pageLabel = 'Halaman peraturan',
    this.note,
  });

  final RegulationKind kind;

  /// Contoh: "Undang-Undang Nomor 37 Tahun 2004".
  final String number;

  /// Judul resmi ("tentang ...").
  final String title;

  /// Satu-dua kalimat: kenapa penting bagi kurator/pengurus.
  final String summary;

  /// Tautan langsung ke berkas PDF (bila ada).
  final String? pdfUrl;

  /// Tautan ke halaman peraturan (informasi status/perubahan).
  final String? pageUrl;
  final String pageLabel;

  /// Catatan perubahan atau hal yang perlu dicek.
  final String? note;

  String get searchText => '$number $title $summary ${kind.label}'.toLowerCase();
}

/// Daftar bawaan (sama dengan situs, per Oktober 2026). Bila database berisi daftar peraturan
/// (tabel site_regulations, dikelola dari panel admin situs), aplikasi memakai daftar dari database.
const regulations = <Regulation>[
  Regulation(
    kind: RegulationKind.uu,
    number: 'UU No. 37 Tahun 2004',
    title: '',
    summary: 'Kepailitan dan Penundaan Kewajiban Pembayaran Utang. Pasal 223 dicabut oleh UU No. 4 Tahun 2023 (P2SK). Beberapa pasal telah ditafsirkan Mahkamah Konstitusi, lihat putusan di bawah.',
    pdfUrl: 'https://peraturan.go.id/files/uu37-2004.pdf',
    pageUrl: 'https://peraturan.bpk.go.id/Details/40784/uu-no-37-tahun-2004',
    pageLabel: 'Status',
  ),
  Regulation(
    kind: RegulationKind.permen,
    number: 'Permenkum No. 20 Tahun 2025',
    title: '',
    summary: 'Pedoman imbalan jasa bagi kurator dan pengurus. Berlaku sejak 27 Mei 2025, menggantikan Permenkumham No. 18 Tahun 2021.',
    pageUrl: 'https://pasal.id/peraturan/permen/permenkum-no-20-tahun-2025',
    pageLabel: 'Lihat',
  ),
  Regulation(
    kind: RegulationKind.permen,
    number: 'Permenkumham No. 37 Tahun 2018',
    title: '',
    summary: 'Syarat dan tata cara pendaftaran serta penyampaian laporan kurator dan pengurus. Masih berlaku.',
    pdfUrl: 'https://peraturan.go.id/files/bn1686-2018.pdf',
    pageUrl: 'https://pasal.id/peraturan/permen/permenkumham-no-37-tahun-2018',
    pageLabel: 'Status',
  ),
  Regulation(
    kind: RegulationKind.putusan,
    number: 'Putusan MK No. 243/PUU-XXIV/2026',
    title: '',
    summary: '29 September 2026. Pasal 127 ayat (1) dan penjelasannya: bila hakim pengawas tidak dapat mendamaikan, perselisihan diselesaikan di pengadilan (pengadilan negeri, pengadilan tinggi, atau MA) untuk perkara yang diajukan sebelum putusan pailit.',
    pageUrl: 'https://pasal.id/peraturan/putusan-mk/puu-mk-243-2026',
    pageLabel: 'Lihat',
  ),
  Regulation(
    kind: RegulationKind.putusan,
    number: 'Putusan MK No. 181/PUU-XXIII/2025',
    title: '',
    summary: '25 Mei 2026. Penjelasan Pasal 292: harta pailit berada dalam keadaan insolvensi sejak dinyatakan hakim pengawas dalam rapat kreditor dan dicatat dalam berita acara.',
    pageUrl: 'https://pasal.id/peraturan/putusan-mk/puu-mk-181-2025',
    pageLabel: 'Lihat',
  ),
  Regulation(
    kind: RegulationKind.putusan,
    number: 'Putusan MK No. 14/PUU-XXIV/2026',
    title: '',
    summary: '25 Mei 2026. Permohonan atas Pasal 292 ditolak: rujukan ke Pasal 286 dan larangan menawarkan perdamaian kembali tetap berlaku.',
    pageUrl: 'https://pasal.id/peraturan/putusan-mk/puu-mk-14-2026',
    pageLabel: 'Lihat',
  ),
  Regulation(
    kind: RegulationKind.putusan,
    number: 'Putusan MK No. 74/PUU-XXIV/2026',
    title: '',
    summary: '29 April 2026. Pasal 74 ayat (1): kurator melapor ke hakim pengawas tiap 3 bulan, dengan tembusan kepada kreditor dan debitor pailit.',
    pdfUrl: 'https://s.mkri.id/public/content/persidangan/putusan/putusan_mkri_14183_1777450375.pdf',
  ),
  Regulation(
    kind: RegulationKind.rancangan,
    number: 'RUU Profesi Kurator',
    title: '',
    summary: 'Usul inisiatif DPR sejak April 2026. PERKAPI mendorongnya masuk Prolegnas Prioritas. Masih rancangan dan belum berlaku.',
    pageUrl: 'https://www.hukumonline.com/berita/a/pemerintah-dpr-sepakat-6-ruu-ini-jadi-usul-inisiatif-dpr-lt69e0455bc1771/',
    pageLabel: 'Baca beritanya',
  ),
];

/// Satu baris dari RPC `public_regulations` (situs & aplikasi memakai daftar yang sama).
Regulation regulationFromRow(Map<String, dynamic> r) {
  final kind = switch ('${r['kind']}') {
    'Undang-Undang' => RegulationKind.uu,
    'Peraturan Menteri' => RegulationKind.permen,
    'Putusan MK' => RegulationKind.putusan,
    _ => RegulationKind.rancangan,
  };
  String? s(Object? v) => (v == null || '$v'.trim().isEmpty) ? null : '$v'.trim();
  return Regulation(
    kind: kind,
    number: '${r['number'] ?? ''}',
    title: '',
    summary: '${r['summary'] ?? ''}',
    pdfUrl: s(r['pdf_url']),
    pageUrl: s(r['page_url']),
    pageLabel: s(r['page_label']) ?? 'Lihat',
  );
}

/// Portal resmi untuk mencari peraturan lain (perubahan, PP, SEMA/PERMA, dll.).
const regulationPortals = <(String, String, String)>[
  ('JDIH BPK', 'Database peraturan nasional dengan status berlaku/dicabut', 'https://peraturan.bpk.go.id'),
  ('Peraturan.go.id', 'Portal peraturan resmi (naskah PDF Lembaran/Berita Negara)', 'https://peraturan.go.id'),
  ('AHU Online', 'Pendaftaran dan laporan kurator/pengurus', 'https://ahu.go.id'),
];
