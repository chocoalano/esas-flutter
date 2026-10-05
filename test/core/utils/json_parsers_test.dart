import 'package:esas/core/utils/json_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('asInt', () {
    test('accepts every shape the backend actually sends', () {
      // The attendance QR carries departement_id and id as JSON values whose
      // type is not guaranteed. The old code called int.tryParse on them, which
      // takes a non-nullable String and throws a TypeError outright when handed
      // a number (CRIT-04).
      expect(asInt(12), 12);
      expect(asInt('12'), 12);
      expect(asInt(' 12 '), 12);
      expect(asInt(12.0), 12);
      expect(asInt(12.7), 12);
    });

    test('is null rather than throwing for what is not a number', () {
      expect(asInt(null), isNull);
      expect(asInt(''), isNull);
      expect(asInt('  '), isNull);
      expect(asInt('abc'), isNull);
      expect(asInt({'id': 1}), isNull);
      expect(asInt([1]), isNull);
    });
  });

  group('the department check that fails open', () {
    // CRIT-04. `if (storageDeptId == qrDeptId)` passes when BOTH are null,
    // because null == null is true — so a stale user object plus an unparseable
    // QR submits attendance with a null user_id. These cases pin the parsing
    // half; the guard itself is fixed in Phase 4 with these as its baseline.
    int? deptFrom(Object? raw) => asInt(raw);

    test('a numeric QR id parses instead of throwing', () {
      expect(deptFrom(7), 7);
    });

    test('a string QR id parses', () {
      expect(deptFrom('7'), 7);
    });

    test('an absent id is null, so a guard can refuse it explicitly', () {
      expect(deptFrom(null), isNull);
      expect(deptFrom(''), isNull);
    });

    test('two nulls must never be treated as a match', () {
      final storage = deptFrom(null);
      final qr = deptFrom(null);

      // What the current code does — and why it is wrong.
      expect(storage == qr, isTrue);

      // What the fix must require instead.
      final matches = storage != null && qr != null && storage == qr;
      expect(matches, isFalse);
    });

    test('a real mismatch is still refused', () {
      final matches =
          deptFrom(3) != null &&
          deptFrom(7) != null &&
          deptFrom(3) == deptFrom(7);
      expect(matches, isFalse);
    });

    test('a real match across mixed types is accepted', () {
      final storage = deptFrom(7);
      final qr = deptFrom('7');
      final matches = storage != null && qr != null && storage == qr;

      expect(matches, isTrue);
    });
  });

  group('asString', () {
    test(
      'treats blank as absent, because the backend uses "" and null alike',
      () {
        expect(asString('Budi'), 'Budi');
        expect(asString('  Budi  '), 'Budi');
        expect(asString(''), isNull);
        expect(asString('   '), isNull);
        expect(asString(null), isNull);
        expect(asString(12), '12');
      },
    );
  });

  group('asDate', () {
    test('never throws on what DateTime.parse would', () {
      // `DateTime.parse(json['created_at'] as String)` appears 8 times in the
      // models and throws twice over on a null: on the cast and on the parse.
      expect(asDate('2025-07-09T02:43:31.000Z')?.year, 2025);
      expect(asDate(null), isNull);
      expect(asDate(''), isNull);
      expect(asDate('not a date'), isNull);
      expect(asDate(1751000000000)?.isUtc, isFalse);
    });
  });

  group('asBool', () {
    test('reads the shapes Laravel sends for a flag', () {
      expect(asBool(true), isTrue);
      expect(asBool(1), isTrue);
      expect(asBool('1'), isTrue);
      expect(asBool('true'), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('false'), isFalse);
      expect(asBool('maybe'), isNull);
      expect(asBool(null), isNull);
    });
  });

  group('asModelList', () {
    test('costs one row, not the whole screen, when a row is malformed', () {
      final rows = asModelList([
        {'id': 1},
        'not an object',
        {'id': 3},
        null,
      ], (json) => asInt(json['id']));

      expect(rows, [1, 3]);
    });

    test('is empty for anything that is not a list', () {
      expect(asModelList(null, (j) => j), isEmpty);
      expect(asModelList({'a': 1}, (j) => j), isEmpty);
    });

    // Enam model masih memakai cast mentah `as String` di `fromJson`, jadi
    // sebuah baris cacat melempar alih-alih sekadar mengurai dengan buruk.
    // Karena `TypeError` bukan `ApiException`, ia melewati `catch` di
    // controller dan menjatuhkan layar — persis yang terjadi pada satu jenis
    // perizinan dengan `type: null`.
    test('keeps the rest of the list when one row throws', () {
      final rows = asModelList(
        [
          {'id': 1},
          {'id': 2},
          {'id': 3},
        ],
        (json) {
          final id = asInt(json['id']);
          if (id == 2) {
            throw const FormatException('baris ini rusak');
          }
          return id;
        },
      );

      expect(rows, [1, 3]);
    });
  });

  group('dig', () {
    test('walks a path and stops at the first gap', () {
      final user = {
        'employee': {
          'job_position': {'name': 'Staff IT'},
        },
      };

      expect(dig(user, ['employee', 'job_position', 'name']), 'Staff IT');
      expect(dig(user, ['employee', 'salary', 'amount']), isNull);
      expect(dig(user, ['missing', 'deep', 'path']), isNull);
      expect(dig(null, ['a']), isNull);
    });

    test('stops rather than throwing when a step is not a map', () {
      expect(dig({'a': 'string'}, ['a', 'b']), isNull);
    });
  });
}
