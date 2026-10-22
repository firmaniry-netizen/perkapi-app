import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/core/widgets/motion.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('Reduce Motion aktif: tanpa pembungkus animasi', () {
    testWidgets('Reveal langsung menampilkan anak', (t) async {
      await t.pumpWidget(_host(const Reveal(child: Text('isi')), reduce: true));
      expect(find.text('isi'), findsOneWidget);
      expect(find.descendant(of: find.byType(Reveal), matching: find.byType(Opacity)), findsNothing);
    });
    testWidgets('CountUp langsung menampilkan angka akhir', (t) async {
      await t.pumpWidget(_host(const CountUp(value: 24), reduce: true));
      expect(find.text('24'), findsOneWidget);
    });
    testWidgets('Sheen tidak menambah lapisan kilau', (t) async {
      await t.pumpWidget(_host(const Sheen(child: Text('kartu')), reduce: true));
      await t.pump(const Duration(seconds: 3));
      expect(find.text('kartu'), findsOneWidget);
      expect(find.descendant(of: find.byType(Sheen), matching: find.byType(Positioned)), findsNothing);
    });
  });

  group('Gerak normal: berakhir di keadaan akhir yang benar', () {
    testWidgets('Reveal berakhir penuh terlihat', (t) async {
      await t.pumpWidget(_host(const Reveal(child: Text('isi'))));
      await t.pumpAndSettle();
      final o = t.widget<Opacity>(find.ancestor(of: find.text('isi'), matching: find.byType(Opacity)).first);
      expect(o.opacity, 1.0);
    });
    testWidgets('CountUp berakhir di nilai akhir', (t) async {
      await t.pumpWidget(_host(const CountUp(value: 24)));
      await t.pumpAndSettle();
      expect(find.text('24'), findsOneWidget);
    });
    testWidgets('CountUp bernilai 0 tidak beranimasi', (t) async {
      await t.pumpWidget(_host(const CountUp(value: 0)));
      expect(find.text('0'), findsOneWidget);
    });
    testWidgets('Sheen: anak tetap tampil dan tidak ada timer tersisa', (t) async {
      await t.pumpWidget(_host(const Sheen(child: Text('kartu'))));
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('kartu'), findsOneWidget);
    });
  });
}
