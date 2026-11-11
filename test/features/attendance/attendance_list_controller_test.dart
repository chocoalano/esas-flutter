import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
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

  group('remediasi wave 4 — riwayat', () {
    Attendance row(int id) =>
        Attendance.fromJson({'id': id, 'date_presence': '2026-11-01'});

    List<Attendance> rows(int from, int count) => [
      for (var i = from; i < from + count; i++) row(i),
    ];

    // ATTP-03. A failed page advanced the counter anyway, and the next scroll
    // asked for the page after it: the failed page was never fetched again and
    // its days looked like days without attendance.
    test('a page that failed is the page asked for again', () async {
      final asked = <int>[];
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int;
        final perPage = invocation.namedArguments[#perPage] as int;
        asked.add(page);
        if (page == 2 && asked.where((p) => p == 2).length == 1) {
          throw const ApiException('Offline', code: 'network_unreachable');
        }
        return AttendanceHistoryPage(rows: rows((page - 1) * perPage, perPage));
      });
      final controller = build();
      await controller.refreshAttendance();

      await controller.loadMore();
      // An error stops the automatic loading; the footer offers a retry.
      await controller.loadMore();
      expect(asked, [1, 2]);

      await controller.retryLoadMore();
      expect(asked, [1, 2, 2]);
    });

    // UAT review A4. A refresh that failed kept the rows on screen — and had
    // already wound the page counter back to 1, so the retry fetched page 2
    // again and appended rows that were already there.
    test('a failed refresh that keeps the rows keeps their page too', () async {
      final asked = <int>[];
      var offline = false;
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((invocation) async {
        final page = invocation.namedArguments[#page] as int;
        final perPage = invocation.namedArguments[#perPage] as int;
        asked.add(page);
        if (offline) {
          throw const ApiException('Offline', code: 'network_unreachable');
        }
        return AttendanceHistoryPage(rows: rows((page - 1) * perPage, perPage));
      });
      final controller = build();
      await controller.refreshAttendance();
      await controller.loadMore();
      final held = controller.attendanceList.length;

      offline = true;
      await controller.refreshAttendance();
      expect(controller.attendanceList, hasLength(held));

      offline = false;
      asked.clear();
      await controller.retryLoadMore();

      expect(asked, [3]);
      final ids = controller.attendanceList.map((a) => a.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'no row twice');
    });

    // ATTP-10. A slower answer for an earlier filter overwrote the newer one.
    test('an answer for an older filter is dropped', () async {
      final slow = Completer<AttendanceHistoryPage>();
      var call = 0;
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) {
        call++;
        return call == 1
            ? slow.future
            : Future.value(AttendanceHistoryPage(rows: rows(100, 2)));
      });
      final controller = build();

      final first = controller.refreshAttendance();
      await controller.togglePreset(AttendanceRangePreset.thisMonth);
      slow.complete(AttendanceHistoryPage(rows: rows(0, 10)));
      await first;

      expect(controller.attendanceList.map((a) => a.id), [100, 101]);
    });

    // ATTP-18. On the 30th, "Bulan ini" and "30 hari terakhir" are the same
    // dates; the chip that lit and the toggle were derived from the dates.
    test('the preset chosen is the preset shown, and toggles off', () async {
      final controller = build();

      await controller.togglePreset(AttendanceRangePreset.last30Days);
      expect(controller.activePreset, AttendanceRangePreset.last30Days);

      await controller.togglePreset(AttendanceRangePreset.last30Days);
      expect(controller.activePreset, isNull);
    });
  });
}
