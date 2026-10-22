import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/page_glow.dart';
import '../../core/widgets/ui_kit.dart';
import '../ahu/ahu_page.dart';
import 'guide_widgets.dart';

// ---------------------------------------------------------------------------
// Beranda Profesi
// ---------------------------------------------------------------------------

/// Pusat menu Profesi: pendaftaran, perpanjangan, dan format laporan ke AHU.
class ProfessionPage extends StatelessWidget {
  const ProfessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    final entries = <(IconData, String, String, String, Color)>[
      (Icons.how_to_reg_outlined, 'Pendaftaran AHU', 'Syarat dokumen, alur, dan masa berlaku surat bukti pendaftaran.', '/profession/registration', AppColors.teal),
      (Icons.autorenew_rounded, 'Perpanjangan AHU', 'Kapan boleh memperpanjang, dokumen yang disiapkan, dan hitung mundur masa berlaku.', '/profession/renewal', AppColors.amber),
      (Icons.assignment_outlined, 'Format Laporan ke AHU', 'Laporan pengangkatan, berkala 3 bulan, akhir, dan pindah alamat, lengkap dengan batas waktunya.', '/profession/reports', AppColors.violet),
      (Icons.gavel_rounded, 'Peraturan & Hukum', 'UU Kepailitan, Permenkumham, dan putusan MK yang bisa diunduh dari sumber resmi.', '/regulations', AppColors.navy),
      (Icons.verified_outlined, 'Data AHU Saya', 'Isi nomor dan tanggal surat bukti pendaftaran Anda, lalu minta verifikasi pengelola.', '/ahu', AppColors.navyAction),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Profesi')),
      body: PageGlow(
        accent: AppColors.teal,
        child: ListenableBuilder(
          listenable: Access.instance,
          builder: (context, _) {
            final m = Access.instance.member ?? {};
            final number = '${m['ahu_registration_number'] ?? ''}';
            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                Reveal(
                  index: 0,
                  dy: -12,
                  child: ScreenHero(
                    title: 'Profesi Kurator & Pengurus',
                    subtitle: 'Urusan pendaftaran, perpanjangan, dan pelaporan ke AHU',
                    icon: Icons.workspace_premium_outlined,
                    accent: AppColors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                Reveal(
                  index: 1,
                  child: AppCard(
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Status AHU Anda', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sc.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          AhuBadge(number: number, verified: m['ahu_verified'] == true),
                          if (number.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Berlaku s.d. ${ahuDate(m['ahu_valid_until'])}', style: TextStyle(fontSize: 13, color: sc.onSurfaceVariant)),
                          ],
                        ]),
                      ),
                      TextButton(onPressed: () => openAhuOnline(context), child: const Text('AHU Online')),
                    ]),
                  ),
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < entries.length; i++) ...[
                  const SizedBox(height: 12),
                  Reveal(
                    index: i + 2,
                    child: AppCard(
                      onTap: () => context.push(entries[i].$4),
                      child: Row(children: [
                        SolidTile(icon: entries[i].$1, color: entries[i].$5, size: 48, radius: 16),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(entries[i].$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(entries[i].$3, style: TextStyle(fontSize: 13, height: 1.35, color: sc.onSurfaceVariant)),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: sc.onSurfaceVariant),
                      ]),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pendaftaran
// ---------------------------------------------------------------------------

class AhuRegistrationGuidePage extends StatelessWidget {
  const AhuRegistrationGuidePage({super.key});

  static const _docs = <String>[
    'Kartu tanda penduduk',
    'Nomor pokok wajib pajak',
    'Sertifikat tanda lulus ujian Kurator dan Pengurus dari Komite Bersama',
    'Surat rekomendasi dari Organisasi Profesi Kurator dan Pengurus',
    'Surat pernyataan tidak rangkap jabatan',
    'Surat pernyataan bersedia membuka rekening untuk setiap perkara kepailitan atas nama debitur pailit',
    'Surat pernyataan tidak sedang dalam keadaan pailit',
    'Surat pernyataan tidak pernah menjadi direksi atau komisaris yang dinyatakan bersalah sehingga perseroan pailit',
    'Surat pernyataan tidak pernah dihukum karena tindak pidana yang diancam pidana 5 tahun atau lebih (putusan berkekuatan hukum tetap)',
    'Surat pernyataan bersedia menjalankan tugas pengurusan dan pemberesan harta pailit serta bertanggung jawab atas kesalahan atau kelalaian yang merugikan harta pailit',
    'Surat pernyataan bersedia dihapus dari daftar jika terbukti melanggar kode etik dan peraturan perundang-undangan',
    'Surat keterangan sehat jasmani dan rohani dari rumah sakit pemerintah',
    'Surat keterangan catatan kepolisian',
    'Pas foto terbaru berwarna, latar putih, ukuran 4 x 6 cm',
    'Surat keterangan terdaftar sebagai advokat, atau terdaftar sebagai akuntan publik, dari organisasi profesinya',
    'Surat keterangan telah bekerja di kantor advokat atau kantor akuntan publik paling singkat 3 tahun',
    'Ijazah sarjana hukum, atau fotokopi ijazah sarjana ekonomi yang dilegalisir perguruan tinggi',
  ];

  @override
  Widget build(BuildContext context) {
    return GuideScaffold(
      title: 'Pendaftaran AHU',
      accent: AppColors.teal,
      hero: ScreenHero(
        title: 'Pendaftaran Kurator & Pengurus',
        subtitle: 'Syarat dokumen, alur pengajuan, dan masa berlaku',
        icon: Icons.how_to_reg_outlined,
        accent: AppColors.teal,
      ),
      children: [
        const GuideCard(
          title: 'Alur pengajuan',
          child: GuideList(numbered: true, [
            'Siapkan seluruh dokumen persyaratan dalam bentuk berkas digital.',
            'Ajukan permohonan melalui laman resmi Direktorat Jenderal Administrasi Hukum Umum (AHU) dan unggah dokumennya.',
            'Bayar biaya sesuai ketentuan Penerimaan Negara Bukan Pajak (PNBP) yang berlaku.',
            'AHU memverifikasi administrasi secara elektronik paling lama 3 hari kerja sejak permohonan diterima.',
            'Jika ada dokumen kurang, Anda diberi tahu secara elektronik dan harus melengkapinya paling lama 14 hari kerja.',
            'Jika dokumen lengkap, surat bukti pendaftaran terbit dan dikirim secara elektronik lewat laman AHU.',
          ]),
        ),
        const SizedBox(height: 12),
        const GuideCallout(
          icon: Icons.warning_amber_rounded,
          color: AppColors.amber,
          text: 'Jika kekurangan dokumen tidak dilengkapi dalam 14 hari kerja, permohonan ditolak dan biaya yang sudah dibayar tidak dikembalikan. Anda boleh mengajukan lagi setelah ditolak.',
        ),
        const GuideCard(
          title: 'Dokumen yang harus disiapkan',
          subtitle: 'Centang untuk menandai dokumen yang sudah siap. Daftar ini hanya pengingat dan tidak tersimpan.',
          child: GuideChecklist(_docs),
        ),
        const SizedBox(height: 12),
        const GuideCallout(
          text: 'Kebenaran semua dokumen menjadi tanggung jawab penuh pemohon. Surat bukti pendaftaran dapat dicetak sendiri di kertas putih ukuran F4/folio 80 gram.',
        ),
        const GuideCard(
          title: 'Masa berlaku',
          child: GuideList([
            'Surat bukti pendaftaran berlaku 5 tahun sejak tanggal diterbitkan.',
            'Setelah itu dapat diperpanjang (lihat menu Perpanjangan AHU).',
          ]),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Isi data AHU saya', icon: Icons.edit_note_rounded, onPressed: () => context.push('/ahu')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openAhuOnline(context),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Buka AHU Online'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const GuideSource(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Perpanjangan
// ---------------------------------------------------------------------------

class AhuRenewalPage extends StatelessWidget {
  const AhuRenewalPage({super.key});

  static const _docs = <String>[
    'Kartu tanda penduduk',
    'Tanda keanggotaan Organisasi Profesi Kurator atau Pengurus, dilegalisir oleh organisasi profesi',
    'Sertifikat pelatihan lanjutan Kurator dan Pengurus dari Komite Bersama',
    'Pas foto terbaru berwarna, latar putih, ukuran 4 x 6 cm',
  ];

  DateTime? _parse(dynamic v) => DateTime.tryParse('${v ?? ''}');

  @override
  Widget build(BuildContext context) {
    final sc = Theme.of(context).colorScheme;
    return GuideScaffold(
      title: 'Perpanjangan AHU',
      accent: AppColors.amber,
      hero: ScreenHero(
        title: 'Perpanjangan Surat Bukti',
        subtitle: 'Berlaku 5 tahun, dapat diperpanjang tiap 5 tahun',
        icon: Icons.autorenew_rounded,
        accent: AppColors.amber,
      ),
      children: [
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Access.instance,
          builder: (context, _) {
            final m = Access.instance.member ?? {};
            final reg = _parse(m['ahu_registration_date']);
            var until = _parse(m['ahu_valid_until']);
            var estimated = false;
            if (until == null && reg != null) {
              until = DateTime(reg.year + 5, reg.month, reg.day);
              estimated = true;
            }
            if (until == null) {
              return AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Masa berlaku Anda belum diketahui', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Isi tanggal terbit atau tanggal berlaku di Data AHU Saya agar hitung mundur muncul di sini.',
                      style: TextStyle(height: 1.4, color: sc.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/ahu'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Isi data AHU saya'),
                  ),
                ]),
              );
            }
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final daysLeft = DateTime(until.year, until.month, until.day).difference(today).inDays;
            final opens = DateTime(until.year, until.month - 3, until.day);
            final (String head, String body, Color color, IconData icon) = daysLeft < 0
                ? ('Masa berlaku sudah lewat', 'Sudah lewat ${-daysLeft} hari. Segera hubungi Organisasi Profesi Anda dan periksa status di AHU Online.', AppColors.red, Icons.error_outline_rounded)
                : !today.isBefore(DateTime(opens.year, opens.month, opens.day))
                    ? ('Sudah bisa diperpanjang', 'Sisa $daysLeft hari. Jendela pengajuan sudah dibuka sejak ${ahuDate(opens.toIso8601String())}.', AppColors.amber, Icons.event_available_rounded)
                    : ('Belum waktunya', 'Sisa $daysLeft hari. Pengajuan baru dapat dilakukan mulai ${ahuDate(opens.toIso8601String())}.', AppColors.emerald, Icons.schedule_rounded);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GuideCallout(icon: icon, color: color, text: '$head. $body'),
              const SizedBox(height: 10),
              Text(
                estimated
                    ? 'Berlaku sampai ${ahuDate(until.toIso8601String())} (perkiraan: 5 tahun sejak tanggal terbit). Isi tanggal berlaku di Data AHU Saya jika berbeda.'
                    : 'Berlaku sampai ${ahuDate(until.toIso8601String())}.',
                style: TextStyle(fontSize: 13, color: sc.onSurfaceVariant),
              ),
            ]);
          },
        ),
        const GuideCard(
          title: 'Ketentuan waktu',
          child: GuideList([
            'Perpanjangan dilakukan setiap 5 tahun sekali.',
            'Permohonan dapat diajukan mulai 3 bulan sebelum masa berlaku surat bukti habis.',
            'Pengajuan lewat laman resmi AHU dan dikenai biaya PNBP.',
          ]),
        ),
        const GuideCard(
          title: 'Dokumen yang disiapkan',
          subtitle: 'Centang untuk menandai dokumen yang sudah siap. Daftar ini hanya pengingat dan tidak tersimpan.',
          child: GuideChecklist(_docs),
        ),
        const GuideCard(
          title: 'Setelah mengajukan',
          child: GuideList([
            'Verifikasi dan kelengkapan dokumen mengikuti tata cara yang sama dengan pendaftaran awal: verifikasi paling lama 3 hari kerja, dan kekurangan dilengkapi paling lama 14 hari kerja.',
            'Setelah surat bukti baru terbit, perbarui nomor dan tanggalnya di Data AHU Saya agar kartu anggota dan verifikasi QR tetap sesuai.',
          ]),
        ),
        const SizedBox(height: 12),
        const GuideCallout(
          icon: Icons.warning_amber_rounded,
          color: AppColors.amber,
          text: 'Kurator atau Pengurus yang sudah dihapus tetap dari daftar tidak dapat mengajukan perpanjangan.',
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Perbarui data AHU saya', icon: Icons.edit_note_rounded, onPressed: () => context.push('/ahu')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openAhuOnline(context),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Buka AHU Online'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const GuideSource(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Format laporan
// ---------------------------------------------------------------------------

class AhuReportFormatPage extends StatelessWidget {
  const AhuReportFormatPage({super.key});

  static const _tplAppointment = '''LAPORAN PENGANGKATAN KURATOR/PENGURUS
Kepada: Direktur Jenderal Administrasi Hukum Umum (melalui laman resmi AHU)

1. Nomor dan tanggal putusan pailit/PKPU : ...
2. Debitor
   - Nama : ...
   - Alamat : ...
   - Pekerjaan/bidang usaha : ...
3. Hakim Pengawas : ...
4. Kurator/Pengurus
   - Nama : ...
   - Alamat kantor : ...
   - Pekerjaan : ...
5. Anggota panitia kreditor sementara (jika sudah ditunjuk)
   - Nama / alamat / pekerjaan : ...
6. Bukti pengumuman di 2 (dua) surat kabar harian : (lampirkan)
7. Bukti pembayaran pengumuman di Berita Negara RI : (lampirkan)
8. Tempat dan waktu rapat kreditor pertama : ...
''';

  static const _tplPeriodic = '''LAPORAN PEKERJAAN KURATOR/PENGURUS - PERIODE ... s.d. ... (3 bulan)
Kepada: Hakim Pengawas (tembusan: Direktur Jenderal AHU melalui laman resmi AHU)
Perkara: ... Nomor putusan: ...

A. Hal-hal yang terjadi selama periode pelaporan, termasuk tindakan hukum
   1. Hasil rapat kreditur pertama : ...
   2. Rapat verifikasi piutang : ...
   3. Lelang : ...
   4. Pemberesan : ...
   5. Tindakan hukum lainnya : ...
B. Jumlah pembayaran yang dilakukan kepada para kreditur : Rp ...
C. Sisa utang yang belum terlunasi
   - Pokok : Rp ...
   - Bunga : Rp ...
''';

  static const _tplFinal = '''LAPORAN AKHIR PENGURUSAN DAN PEMBERESAN
Kepada: Direktur Jenderal Administrasi Hukum Umum (melalui laman resmi AHU)
Perkara: ...

Lampiran yang diunggah:
 - Nomor dan tanggal putusan pengakhiran kepailitan/PKPU : ...
 - Bukti pembayaran pengumuman di Berita Negara RI : (lampirkan)
 - Bukti pengumuman di 2 (dua) surat kabar harian : (lampirkan)

Isi laporan:
 1. Rangkuman keputusan-keputusan utama terkait pengelolaan budel pailit sejak kepailitan dimulai
 2. Daftar semua harta yang tercatat pada pembukaan kepailitan
 3. Daftar semua harta yang diperoleh selama pengurusan dan pemberesan
 4. Daftar semua penjualan budel pailit beserta hasil penjualannya
 5. Daftar semua pembayaran selama pengurusan dan pemberesan: pihak penerima, jumlah, tanggal, dan maksud pembayaran
''';

  static const _tplAddress = '''LAPORAN PINDAH ALAMAT KANTOR KURATOR/PENGURUS
Kepada: Direktur Jenderal Administrasi Hukum Umum (melalui laman resmi AHU)

Nama : ...
Nomor surat bukti pendaftaran : ...
Alamat kantor lama : ...
Alamat kantor baru : ...
Tanggal efektif pindah : ...
''';

  Widget _report({
    required String title,
    required String deadline,
    required String to,
    required List<String> contents,
    required String template,
    Color color = AppColors.violet,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GuideCard(
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GuideCallout(icon: Icons.schedule_rounded, color: color, text: 'Batas waktu: $deadline'),
          const SizedBox(height: 12),
          Text('Disampaikan kepada: $to', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 12),
          const Text('Isi paling sedikit', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GuideList(contents),
          const SizedBox(height: 16),
          CopyButton(text: template),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GuideScaffold(
      title: 'Format Laporan ke AHU',
      accent: AppColors.violet,
      hero: ScreenHero(
        title: 'Format Laporan ke AHU',
        subtitle: 'Empat laporan yang wajib disampaikan Kurator & Pengurus',
        icon: Icons.assignment_outlined,
        accent: AppColors.violet,
      ),
      children: [
        _report(
          title: '1. Laporan pengangkatan',
          deadline: 'paling lama 14 hari kerja sejak putusan pailit diterima oleh Kurator/Pengurus dan hakim pengawas.',
          to: 'Direktur Jenderal AHU, secara elektronik lewat laman resmi AHU',
          contents: const [
            'Nomor dan tanggal putusan pailit',
            'Nama, alamat, dan pekerjaan debitor',
            'Nama hakim pengawas',
            'Nama, alamat, dan pekerjaan Kurator dan Pengurus',
            'Nama, alamat, dan pekerjaan anggota panitia kreditor sementara, jika sudah ditunjuk',
            'Bukti pengumuman di 2 surat kabar harian',
            'Bukti pembayaran pengumuman di Berita Negara Republik Indonesia',
            'Tempat dan waktu rapat kreditor pertama',
          ],
          template: _tplAppointment,
        ),
        _report(
          title: '2. Laporan pekerjaan berkala',
          deadline: 'setiap 3 bulan, sampai pengurusan dan pemberesan harta pailit atau PKPU berakhir.',
          to: 'Hakim Pengawas, dengan tembusan ke Direktur Jenderal AHU lewat laman resmi AHU',
          contents: const [
            'Hal-hal yang terjadi selama periode pelaporan, termasuk tindakan hukum yang dilakukan',
            'Minimal mencakup: hasil rapat kreditur pertama, rapat verifikasi piutang, lelang, atau pemberesan',
            'Jumlah pembayaran yang dilakukan kepada para kreditur',
            'Sisa utang yang belum terlunasi, pokok maupun bunga',
          ],
          template: _tplPeriodic,
          color: AppColors.sky,
        ),
        _report(
          title: '3. Laporan akhir',
          deadline: 'paling lama 30 hari kerja sejak tanggal pengumuman pengakhiran yang dilakukan Kurator/Pengurus.',
          to: 'Direktur Jenderal AHU, secara elektronik lewat laman resmi AHU',
          contents: const [
            'Unggah: nomor dan tanggal putusan pengakhiran kepailitan atau PKPU',
            'Unggah: bukti pembayaran pengumuman Berita Negara RI dan bukti pengumuman di 2 surat kabar harian',
            'Rangkuman keputusan-keputusan utama terkait pengelolaan budel pailit sejak kepailitan dimulai',
            'Daftar harta yang tercatat pada pembukaan kepailitan',
            'Daftar harta yang diperoleh selama pengurusan dan pemberesan',
            'Daftar penjualan budel pailit beserta hasilnya',
            'Daftar pembayaran: pihak penerima, jumlah, tanggal, dan maksudnya',
          ],
          template: _tplFinal,
          color: AppColors.emerald,
        ),
        _report(
          title: '4. Laporan pindah alamat kantor',
          deadline: 'paling lama 7 hari kerja sejak pindah.',
          to: 'Direktur Jenderal AHU, secara elektronik lewat laman resmi AHU',
          contents: const [
            'Alamat kantor lama dan alamat kantor baru',
            'Tanggal efektif pindah',
          ],
          template: _tplAddress,
          color: AppColors.amber,
        ),
        const SizedBox(height: 12),
        const GuideCallout(
          text: 'Format di atas adalah kerangka isian dari ketentuan yang berlaku. Pengiriman tetap dilakukan lewat formulir elektronik di laman resmi AHU, yang isiannya bisa berbeda dari kerangka ini.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openAhuOnline(context),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Buka AHU Online'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const GuideSource(),
      ],
    );
  }
}
