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
        RegulationKind.rancangan => 'Dalam pembahasan',
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

const regulations = <Regulation>[
  Regulation(
    kind: RegulationKind.uu,
    number: 'Undang-Undang Nomor 37 Tahun 2004',
    title: 'Kepailitan dan Penundaan Kewajiban Pembayaran Utang',
    summary: 'Dasar hukum utama kepailitan dan PKPU: syarat pailit, tugas dan kewenangan kurator serta pengurus, rapat kreditor, hingga pemberesan harta pailit.',
    pdfUrl: 'https://peraturan.go.id/files/uu37-2004.pdf',
    pageUrl: 'https://peraturan.bpk.go.id/Details/40784/uu-no-37-tahun-2004',
    pageLabel: 'Status di JDIH BPK',
    note: 'Sudah ada perubahan oleh putusan MK dan undang-undang lain. Misalnya Pasal 223 (PKPU untuk bank, perusahaan efek, asuransi, dan sejenisnya) dicabut oleh UU Nomor 4 Tahun 2023. '
        'PDF di atas adalah naskah asli, jadi cek halaman status sebelum dikutip.',
  ),
  Regulation(
    kind: RegulationKind.permen,
    number: 'Peraturan Menteri Hukum dan HAM Nomor 37 Tahun 2018',
    title: 'Syarat dan Tata Cara Pendaftaran serta Penyampaian Laporan Kurator dan Pengurus',
    summary: 'Syarat dokumen pendaftaran, perpanjangan surat bukti pendaftaran, laporan ke Ditjen AHU, dan penghapusan dari daftar. Menjadi dasar menu Profesi di aplikasi ini.',
    pdfUrl: 'https://peraturan.go.id/files/bn1686-2018.pdf',
    pageUrl: 'https://pasal.id/peraturan/permen/permenkumham-no-37-tahun-2018',
    pageLabel: 'Ringkasan bab (pasal.id)',
    note: 'Menggantikan Permenkumham Nomor 18 Tahun 2013. Pasal.id adalah situs pihak ketiga, jadi rujuk PDF resmi untuk kutipan.',
  ),
  Regulation(
    kind: RegulationKind.permen,
    number: 'Peraturan Menteri Hukum dan HAM Nomor 18 Tahun 2021',
    title: 'Pedoman Imbalan Jasa bagi Kurator dan Pengurus',
    summary: 'Pedoman besaran dan cara penetapan imbalan jasa kurator, kurator sementara, dan pengurus.',
    pageUrl: 'https://pasal.id/peraturan/permen/permenkumham-no-18-tahun-2021',
    pageLabel: 'Buka peraturan (pasal.id)',
    note: 'Menggantikan Permenkumham 11/2016 jo. 2/2017. Perkara yang sudah berjalan sebelum berlakunya tetap memakai aturan lama. '
        'Tautan PDF resmi belum saya temukan, silakan cari di portal resmi di bagian bawah halaman.',
  ),
  Regulation(
    kind: RegulationKind.putusan,
    number: 'Putusan MK Nomor 74/PUU-XXIV/2026',
    title: 'Pengujian Pasal 74 ayat (1) UU 37/2004 (laporan kurator kepada hakim pengawas)',
    summary: 'Menyatakan Pasal 74 ayat (1) bersyarat: kurator melapor ke hakim pengawas tiap 3 bulan, dengan tembusan ke kreditor dan debitor pailit lewat surat tercatat, surel, atau aplikasi.',
    pdfUrl: 'https://s.mkri.id/public/content/persidangan/putusan/putusan_mkri_14183_1777450375.pdf',
    pageUrl: 'https://literasihukum.com/putusan-mk/4391/74puu-xxiv2026',
    pageLabel: 'Ringkasan putusan',
    note: 'Putusan terbaru, jadi periksa dulu apakah praktik pelaporan di pengadilan niaga Anda sudah menyesuaikan.',
  ),
  Regulation(
    kind: RegulationKind.rancangan,
    number: 'RUU Profesi Kurator',
    title: 'Rancangan undang-undang khusus profesi kurator (masuk Prolegnas)',
    summary: 'Diusulkan untuk mengatur standar profesi, pengawasan, tugas, tanggung jawab, dan perlindungan kurator, terpisah dari UU 37/2004. PERKAPI menyampaikan masukan dalam rapat dengar pendapat umum dengan Komisi XIII DPR pada 15 September 2026.',
    pageUrl: 'https://www.rctiplus.com/news/detail/inews/5473832/perkapi-rapat-bareng-komisi-xiii-dpr--dorong-ruu-profesi-kurator-jadi-prioritas',
    pageLabel: 'Baca beritanya',
    note: 'Ini masih rancangan dan belum berlaku, jadi belum bisa dijadikan dasar hukum. Pantau perkembangannya di portal DPR atau JDIH.',
  ),
];

/// Portal resmi untuk mencari peraturan lain (perubahan, PP, SEMA/PERMA, dll.).
const regulationPortals = <(String, String, String)>[
  ('JDIH BPK', 'Database peraturan nasional dengan status berlaku/dicabut', 'https://peraturan.bpk.go.id'),
  ('Peraturan.go.id', 'Portal peraturan resmi (naskah PDF Lembaran/Berita Negara)', 'https://peraturan.go.id'),
  ('AHU Online', 'Pendaftaran dan laporan kurator/pengurus', 'https://ahu.go.id'),
];
