import 'package:flutter_test/flutter_test.dart';
import 'package:perkapi/core/services/access_service.dart';

void main() {
  final a = Access.instance;
  setUp(a.clear);

  group('can()', () {
    test('izin null selalu boleh', () => expect(a.can(null), isTrue));
    test('tanpa izin -> ditolak', () => expect(a.can('view_case'), isFalse));
    test('punya izin -> boleh', () {
      a.permissions = {'view_case'};
      expect(a.can('view_case'), isTrue);
      expect(a.can('manage_member'), isFalse);
    });
    test('admin utama boleh semua', () {
      a.isSuper = true;
      expect(a.can('izin_apa_saja'), isTrue);
    });
  });

  group('profil', () {
    test('roleLabel: tanpa peran = ANGGOTA, garis bawah jadi spasi', () {
      expect(a.roleLabel, 'ANGGOTA');
      a.roles = ['SUPER_ADMIN'];
      expect(a.roleLabel, 'SUPER ADMIN');
    });
    test('persetujuan: default approved; pending tidak lolos', () {
      expect(a.isApproved, isTrue); // kolom belum ada -> dianggap approved
      a.member = {'approval_status': 'pending'};
      expect(a.isApproved, isFalse);
      a.member = {'approval_status': 'approved'};
      expect(a.isApproved, isTrue);
    });
    test('avatarPath: string kosong dianggap tidak ada', () {
      a.member = {'avatar_path': ''};
      expect(a.avatarPath, isNull);
      a.member = {'avatar_path': 'members/1.jpg'};
      expect(a.avatarPath, 'members/1.jpg');
    });
    test('clear() mengosongkan semuanya', () {
      a.member = {'id': 'x'};
      a.permissions = {'p'};
      a.isSuper = true;
      a.clear();
      expect(a.member, isNull);
      expect(a.permissions, isEmpty);
      expect(a.isSuper, isFalse);
    });
  });
}
