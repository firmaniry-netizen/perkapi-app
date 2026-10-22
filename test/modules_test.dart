import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/shared/models/modules.dart';

void main() {
  test('semua modul punya tabel, judul, dan field', () {
    for (final m in modules.values) {
      expect(m.table, isNotEmpty);
      expect(m.fields, isNotEmpty);
      expect(m.id, modules.entries.firstWhere((e) => e.value == m).key);
    }
  });
}
