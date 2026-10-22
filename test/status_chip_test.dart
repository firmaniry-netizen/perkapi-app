import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/shared/widgets/state_widgets.dart';

void main() {
  const hijau = Color(0xFF1B7F4B), kuning = Color(0xFFB26A00), merah = Color(0xFFB3261E), biru = Color(0xFF3B5BA5);
  Color tone(String s) => StatusChip.toneFor(s);

  test('status positif berwarna hijau', () {
    for (final s in ['Aktif', 'Selesai', 'Disetujui', 'Lunas', 'Hadir']) {
      expect(tone(s), hijau, reason: s);
    }
  });
  test('status menunggu berwarna kuning', () {
    for (final s in ['Menunggu Persetujuan', 'Diproses', 'Draft', 'Belum selesai']) {
      expect(tone(s), kuning, reason: s);
    }
  });
  test('status negatif/mendesak berwarna merah', () {
    for (final s in ['Ditolak', 'Dibatalkan', 'Gagal', 'Terlambat', 'Mendesak']) {
      expect(tone(s), merah, reason: s);
    }
  });
  test('"Nonaktif" dan "Tidak hadir" TIDAK boleh hijau (mengandung kata aktif/hadir)', () {
    expect(tone('Nonaktif'), merah);
    expect(tone('Tidak hadir'), merah);
  });
  test('status tak dikenal berwarna biru netral', () {
    expect(tone('Berjalan'), biru);
  });
  test('fmtValue: null kosong, tanggal ISO dipotong, lainnya apa adanya', () {
    expect(fmtValue(null), '');
    expect(fmtValue('2026-10-06T09:30:00+00:00'), '2026-10-06');
    expect(fmtValue(42), '42');
    expect(fmtValue('PKPU No. 112'), 'PKPU No. 112');
  });
}
