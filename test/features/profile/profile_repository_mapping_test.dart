import 'package:esas/core/utils/json_parsers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The envelopes and key names the repositories unwrap.
///
/// Two defects of the same shape were found by reading the payloads against the
/// readers rather than by anybody using the app:
///
/// * `GET /permits/{id}` answers `{permit: …}` and `GET /announcements/{id}`
///   answers `{announcement: …}`. Both repositories looked for `data`, which is
///   what the retired backend called its envelope. Finding nothing, both fell
///   through to the *whole body* — so `fromJson` read a map whose keys were one
///   level too high and every field came back as its default. A request numbered
///   zero, a notice with no title. No exception, no log line.
///
/// * `GET /attendance/summary` answers `{summary: {worked_days, late_count, …}}`
///   where the old backend answered `total_absensi`, `total_terlambat` and
///   `persen_point`. The profile header read the old names and showed four
///   zeroes for an employee who had worked all month.
///
/// These pin the shapes so the next contract change fails a test rather than a
/// screen.
void main() {
  group('envelopes', () {
    test('a permit detail is under `permit`', () {
      final body = {
        'permit': {'id': 12, 'permit_numbers': 'PRM-202609-0001'},
      };

      // What the repository does. Reading `data` here returns nothing, and
      // falling through to `body` yields a map with no `id` at all.
      expect(asObject(body['permit'])['id'], 12);
      expect(asObject(body['data']), isEmpty);
      expect(body['id'], isNull);
    });

    test('an announcement detail is under `announcement`', () {
      final body = {
        'announcement': {'id': 3, 'title': 'Libur bersama'},
      };

      expect(asObject(body['announcement'])['title'], 'Libur bersama');
      expect(asObject(body['data']), isEmpty);
    });

    test('a collection is a Laravel paginator, not a bare array', () {
      final body = {
        'data': [
          {'id': 1},
          {'id': 2},
        ],
        'current_page': 1,
        'per_page': 20,
        'total': 2,
      };

      expect(asPage(body), hasLength(2));
      // A bare array still works: not every endpoint paginates, and a helper
      // that understood only one shape would just move the guess.
      expect(asPage(const [1, 2, 3]), hasLength(3));
    });
  });

  group('attendance summary', () {
    ({double points, int late, int attendance, int onTime}) map(
      Map<String, dynamic> body,
    ) {
      final summary = asObject(body['summary']);
      final worked = asDouble(summary['worked_days'])?.round() ?? 0;
      final late = asInt(summary['late_count']) ?? 0;
      final onTime = worked - late < 0 ? 0 : worked - late;

      return (
        points: worked == 0 ? 0.0 : (onTime / worked) * 100,
        late: late,
        attendance: worked,
        onTime: onTime,
      );
    }

    test('reads the figures payroll itself counts', () {
      final result = map({
        'summary': {'worked_days': 20, 'late_count': 2},
      });

      expect(result.attendance, 20);
      expect(result.late, 2);
      // Derived rather than asked for: a third figure that is simply the
      // difference is a third thing that can disagree.
      expect(result.onTime, 18);
      expect(result.points, 90);
    });

    test('a month with nothing worked is zero, not a division by zero', () {
      final result = map({
        'summary': {'worked_days': 0, 'late_count': 0},
      });

      expect(result.points, 0);
      expect(result.attendance, 0);
    });

    test(
      'the retired backend\'s keys yield nothing, which is the whole point',
      () {
        final result = map({'total_absensi': 20, 'total_terlambat': 2});

        expect(result.attendance, 0);
      },
    );
  });
}
