/// Format tanggal & jam berbahasa Indonesia tanpa bergantung pada data locale `intl`
/// (tidak perlu initializeDateFormatting). Semua waktu ditampilkan dalam zona waktu perangkat.
class FmtId {
  FmtId._();

  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static const monthsLong = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  static const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const daysLong = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  static String _2(int n) => n.toString().padLeft(2, '0');

  /// Baca nilai dari database (ISO dengan/tanpa jam) menjadi waktu lokal. Null bila tidak valid.
  static DateTime? parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toLocal();
    return DateTime.tryParse('$v')?.toLocal();
  }

  /// True bila nilai mentah membawa komponen jam (bukan tanggal saja).
  static bool hasTime(dynamic v) => v != null && RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}').hasMatch('$v');

  /// "21 Okt 2026"
  static String date(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';

  /// "Rab, 21 Okt 2026"
  static String dayDate(DateTime d) => '${days[d.weekday - 1]}, ${date(d)}';

  /// "09.30" (penulisan jam baku Indonesia memakai titik)
  static String time(DateTime d) => '${_2(d.hour)}.${_2(d.minute)}';

  /// "Rab, 21 Okt 2026 • 09.30"
  static String dayDateTime(DateTime d) => '${dayDate(d)} • ${time(d)}';

  /// Label relatif singkat untuk agenda: "Hari ini", "Besok", "3 hari lagi", atau tanggal.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(d.year, d.month, d.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Besok';
    if (diff == -1) return 'Kemarin';
    if (diff > 1 && diff < 7) return '$diff hari lagi';
    if (diff < -1 && diff > -7) return '${-diff} hari lalu';
    return dayDate(d);
  }

  /// Format nilai database untuk teks daftar: tanggal saja -> "21 Okt 2026", dengan jam -> "21 Okt 2026 • 09.30".
  static String value(dynamic v) {
    final d = parse(v);
    if (d == null) return '';
    if (!hasTime(v)) return date(d);
    return '${date(d)} • ${time(d)}';
  }
}

/// Waktu relatif singkat untuk kiriman/notifikasi: "baru saja", "5 mnt lalu", "3 jam lalu", "kemarin", atau tanggal.
String agoId(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return FmtId.date(d);
}
