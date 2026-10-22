import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/core/constants/app_colors.dart';

// Rumus kontras WCAG 2.x. Menjaga klaim di app_colors.dart tetap benar bila palet diubah.
double _lin(double s) => s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
double _lum(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('teks putih di tombol merah memenuhi AA (>= 4,5)', () {
    expect(ratio(AppColors.white, AppColors.red), greaterThanOrEqualTo(4.5));
  });
  test('teks putih di dongker memenuhi AAA (>= 7)', () {
    expect(ratio(AppColors.white, AppColors.navy), greaterThanOrEqualTo(7));
  });
  test('teks utama di latar terang memenuhi AAA (>= 7)', () {
    expect(ratio(AppColors.ink, AppColors.paper), greaterThanOrEqualTo(7));
    expect(ratio(AppColors.navy, AppColors.paper), greaterThanOrEqualTo(7));
  });
  test('teks redup tetap terbaca di putih dan kertas (>= 4,5)', () {
    expect(ratio(AppColors.muted, AppColors.white), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.muted, AppColors.paper), greaterThanOrEqualTo(4.5));
  });
  test('mode gelap: merah terang dan teks redup terbaca (>= 4,5)', () {
    expect(ratio(AppColors.redLight, AppColors.navyDeep), greaterThanOrEqualTo(4.5));
    expect(ratio(AppColors.navySoft, AppColors.navySurface), greaterThanOrEqualTo(4.5));
  });
}
