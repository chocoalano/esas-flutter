import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/data/models/attendance_history_page.dart';
import 'package:esas/features/attendance/data/models/attendance_month_totals.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

/// The window the history screen asks about, and the figures it keeps.
///
/// Two bugs are pinned here, both of them about a screen describing a period
/// other than the one it is showing:
///
/// * the client sent no `from`/`to` when nobody had chosen a range, and the
///   endpoint answers an unspecified window with **the current month** — so a
///   screen captioned "Semua tanggal tercatat" held three days on the 3rd, and
///   the seven-day strip drew the days before the 1st as days with no
///   attendance;
/// * the month header's figures were counted from the loaded pages, so a month
///   of twenty-two attendances announced "10 hari tercatat" until somebody
///   scrolled.
void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();

    when(
      () => repository.history(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer(
      (_) async => const AttendanceHistoryPage(rows: <Attendance>[]),
    );
  });

  tearDown(Get.reset);

  AttendanceListController build() =>
      AttendanceListController(repository: repository);

  DateTime today() {
    final now = WorkspaceClock.current.now();

    return DateTime(now.year, now.month, now.day);
  }

  group('the window is always explicit', () {
    test('an unchosen range is the last year, not "unspecified"', () {
      final range = build().effectiveRange;

      expect(range.end, today());
      expect(range.end.difference(range.start).inDays, 364);
    });

    test('a chosen range is used as chosen', () {
      final controller = build()
        ..startDate.value = DateTime(2026, 3, 2)
        ..endDate.value = DateTime(2026, 3, 20);

      expect(controller.effectiveRange.start, DateTime(2026, 3, 2));
      expect(controller.effectiveRange.end, DateTime(2026, 3, 20));
    });

    test('half a range is no range', () {
      // Both ends or neither: a half-open request is a request whose window
      // the server picks and the screen does not know.
      final controller = build()..startDate.value = DateTime(2026, 3, 2);

      expect(controller.effectiveRange.end, today());
      expect(
        controller.effectiveRange.start.isBefore(DateTime(2026, 3, 2)),
        isTrue,
      );
    });
  });

  group('the presets mean exactly what they say', () {
    test('"30 hari terakhir" is today and the twenty-nine before it', () {
      final range = build().rangeOf(AttendanceRangePreset.last30Days);

      expect(range.end, today());
      expect(range.end.difference(range.start).inDays, 29);
    });

    test('"Bulan ini" runs from the first to today, not to month end', () {
      final range = build().rangeOf(AttendanceRangePreset.thisMonth);

      expect(range.start.day, 1);
      expect(range.end, today());
    });

    test('"Bulan lalu" ends on the last day of the previous month', () {
      final range = build().rangeOf(AttendanceRangePreset.lastMonth);
      final now = today();

      expect(range.start.day, 1);
      expect(range.end, DateTime(now.year, now.month, 0));
      expect(range.end.month, range.start.month);
      expect(range.end.year, range.start.year);

      // The month before this one, whichever year that lands in.
      final expected = DateTime(now.year, now.month - 1, 1);
      expect(range.start, expected);
    });
  });

  group('a reversed custom range is straightened, not sent', () {
    test('the ends are swapped', () async {
      final controller = build();
      Get.put<AttendanceListController>(controller);

      await controller.applyDateRange(
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 3),
      );

      // The endpoint answers a reversed range by clamping `to` up to `from`,
      // which turns nineteen days into one without saying so.
      expect(controller.startDate.value, DateTime(2026, 8, 3));
      expect(controller.endDate.value, DateTime(2026, 8, 21));
    });
  });

  group('the month figures come from the page that carries them', () {
    test('a first page installs them', () async {
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => AttendanceHistoryPage(
          rows: const <Attendance>[],
          monthTotals: [
            AttendanceMonthTotals(
              month: DateTime(2026, 9),
              recordedDays: 22,
              lateDays: 3,
              averageClockIn: '08:04',
            ),
          ],
        ),
      );

      final controller = build();
      Get.put<AttendanceListController>(controller);
      await controller.refreshAttendance();

      expect(controller.monthTotals[DateTime(2026, 9)]?.recordedDays, 22);
    });

    test('a page without them keeps what is already held', () async {
      final controller = build();
      Get.put<AttendanceListController>(controller);

      controller.monthTotals[DateTime(2026, 9)] = AttendanceMonthTotals(
        month: DateTime(2026, 9),
        recordedDays: 22,
        lateDays: 3,
        averageClockIn: '08:04',
      );

      // Null means "later page" or "older deployment". Both mean keep what you
      // had rather than wipe the figures the header is drawn from.
      await controller.refreshAttendance();

      expect(controller.monthTotals[DateTime(2026, 9)]?.recordedDays, 22);
    });
  });
}
