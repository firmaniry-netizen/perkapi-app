import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/app/theme.dart';
import 'package:perkapi/core/widgets/perkapi_logo.dart';

void main() {
  testWidgets('PerkapiLogo menampilkan placeholder tanpa asset', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: PerkapiLogo()),
    ));
    await tester.pump();
    expect(find.byType(PerkapiLogo), findsOneWidget);
  });
}
