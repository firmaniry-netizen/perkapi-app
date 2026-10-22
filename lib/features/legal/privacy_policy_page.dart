import 'package:flutter/material.dart';

/// Kebijakan Privasi PERKAPI. Isinya mengikuti data yang BENAR-BENAR diproses kode aplikasi
/// (akun, foto, lokasi absensi, kamera pemindai QR, kunci biometrik/PIN, konten, AI, log).
/// Teks ini bukan nasihat hukum: tinjau bersama penasihat hukum organisasi sebelum rilis publik.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const effective = 'Oktober 2026';

  static const sections = <(String, String)>[
    ('Siapa kami',
        'PERKAPI adalah platform digital organisasi profesi Kurator, Kepailitan & PKPU untuk anggotanya. '
            'Aplikasi ini bukan aplikasi resmi pemerintah. Kebijakan ini menjelaskan data apa yang kami proses, '
            'untuk apa, dan pilihan yang Anda miliki.'),
    ('Data yang kami proses',
        'Akun: nama, email, nomor telepon, cabang, nomor anggota, dan status keanggotaan.\n'
            'Foto profil: hanya jika Anda mengunggahnya.\n'
            'Lokasi: hanya saat Anda melakukan absensi acara. Koordinat disimpan bersama catatan kehadiran.\n'
            'Kamera: hanya saat memindai kode QR anggota. Gambar kamera tidak disimpan.\n'
            'Konten: perkara, dokumen, catatan pribadi, forum, pengaduan, tugas, dan kalender yang Anda buat atau akses.\n'
            'Asisten AI: pesan yang Anda kirim ke asisten AI dan dokumen yang Anda minta diringkas.\n'
            'Log aktivitas: catatan tindakan penting (misalnya masuk dan keluar) untuk keamanan dan audit.'),
    ('Kunci biometrik dan PIN',
        'Kunci biometrik ditangani oleh sistem perangkat Anda. PERKAPI tidak menerima atau menyimpan data sidik jari '
            'atau wajah. PIN aplikasi disimpan di penyimpanan aman perangkat dalam bentuk hash, dan dihapus saat Anda keluar akun.'),
    ('Untuk apa data dipakai',
        'Untuk menjalankan keanggotaan dan fitur aplikasi, mengatur hak akses sesuai peran, mencatat kehadiran, '
            'menjaga keamanan akun, dan menjalankan fitur AI atas permintaan Anda. Kami tidak menjual data Anda dan '
            'tidak menampilkan iklan.'),
    ('Siapa yang dapat melihat data',
        'Pengurus dan anggota lain hanya dapat melihat data sesuai peran dan izin yang diberikan. Catatan pribadi '
            'hanya dapat dilihat oleh Anda dan orang yang Anda pilih untuk diberi akses.'),
    ('Pihak ketiga',
        'Data disimpan pada layanan basis data cloud (Supabase). Pesan asisten AI dan dokumen yang Anda minta '
            'diringkas dikirim melalui server PERKAPI ke layanan AI Anthropic untuk menghasilkan jawaban. '
            'Jangan memasukkan data yang tidak ingin diproses oleh layanan tersebut.'),
    ('Keamanan',
        'Koneksi memakai enkripsi (HTTPS). Akses data dibatasi aturan keamanan di tingkat basis data. Cache offline '
            'di perangkat dihapus saat Anda keluar akun. Tidak ada sistem yang sepenuhnya bebas risiko; gunakan '
            'password yang kuat dan aktifkan PIN atau kunci biometrik.'),
    ('Pilihan dan hak Anda',
        'Anda dapat memperbarui profil, mengganti password, dan menonaktifkan kunci aplikasi kapan saja. '
            'Anda dapat menghapus akun lewat Pengaturan > Hapus akun. Penghapusan menghapus akun login, catatan pribadi, '
            'percakapan AI, notifikasi, foto profil, dan koordinat lokasi absensi Anda.'),
    ('Data yang tetap disimpan',
        'Riwayat organisasi seperti perkara, dokumen, forum, dan log audit tetap disimpan untuk keperluan '
            'kelembagaan, tetapi identitas Anda di dalamnya diganti menjadi "Anggota terhapus".'),
    ('Anak-anak',
        'Aplikasi ini untuk anggota organisasi dan tidak ditujukan bagi anak-anak.'),
    ('Perubahan dan kontak',
        'Kebijakan ini dapat diperbarui; versi terbaru selalu tersedia di halaman ini. '
            'Untuk pertanyaan atau permintaan terkait data Anda, hubungi pengurus PERKAPI melalui menu Pengaduan di aplikasi.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('Berlaku sejak $effective', style: TextStyle(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final (title, body) in sections) ...[
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            Text(body, style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}
