import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/core/services/pin_service.dart';

void main() {
  test('PIN lemah ditolak: angka sama dan urutan naik/turun', () {
    for (final p in ['000000', '111111', '999999', '012345', '123456', '234567', '654321', '987654']) {
      expect(PinService.isWeak(p), isTrue, reason: p);
    }
  });
  test('PIN acak diterima', () {
    for (final p in ['482915', '135790', '908172']) {
      expect(PinService.isWeak(p), isFalse, reason: p);
    }
  });
  test('panjang PIN 6 digit dan batas percobaan 5', () {
    expect(PinService.length, 6);
    expect(PinService.maxAttempts, 5);
  });
}
