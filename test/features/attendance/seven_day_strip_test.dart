import 'dart:async';

import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_day_strip.dart';
import 'package:esas/core/ui/components/app_skeleton.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/data/models/attendance_history_page.dart';
import 'package:esas/features/attendance/data/models/attendance_month_totals.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_list_controller.dart';
import 'package:esas/features/attendance/presentation/views/attendance_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

/// The seven-day strip, and what it is allowed to say.
///
/// The sentence under the cells is the strip's entire accessible content —
/// `AppDayStrip` labels itself with it and excludes everything below — so every
/// test here is really about one question: does the strip only claim things it
/// can support?
///
/// Four defects are pinned, each of which produced blank cells or a false
/// count:
///
/// * it spoke before the first page arrived;
/// * it described seven days from a list that had been filtered elsewhere;
/// * it counted leave and sick days as attendance;
/// * it anchored on the handset's clock rather than the workspace's.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockRepository repository;

  /// A fixed "today" in the workspace's own clock, so the seven-day window is
  /// the same on every machine this runs on.
  final DateTime today = WorkspaceClock.current.now();

  String dayOffset(int back) => DateFormat(
    'yyyy-MM-dd',
  ).format(DateTime(today.year, today.month, today.day - back));

  /// A rostered day, which is what the server sends for an ordinary working
  /// day: `shift`, `shift_in` and `shift_out` alongside the punches.
  ///
  /// The roster matters to every count below. `RecordAttendance::status()`
  /// returns `Normal` unconditionally when a day has no shift, so "hadir" is a
  /// word this screen may only use when there was a shift to be present for —
  /// see the unrostered group at the bottom of this file.
  Attendance row({
    required int back,
    String? statusIn,
    String? statusOut,
    bool rostered = true,
  }) => Attendance.fromJson({
    'id': 100 + back,
    'date_presence': dayOffset(back),
    'status_in': statusIn,
    'status_out': statusOut,
    'time_in': '08:00:00',
    'time_out': '17:00:00',
    if (rostered) ...{
      'shift': 'Shift Pagi',
      'shift_in': '08:00:00',
      'shift_out': '17:00:00',
    },
  });

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

  /// Drive the controller the way the app does: stub the fetch and let its own
  /// `onInit` load. Seeding `attendanceList` directly does not survive, because
  /// `Get.put` runs `onInit` and its first page overwrites whatever was put
  /// there.
  Future<AttendanceListController> pump(
    WidgetTester tester, {
    required List<Attendance> rows,
    List<AttendanceMonthTotals>? monthTotals,
    bool loading = false,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    if (loading) {
      // Never completes, so the screen is caught mid-load — which is the state
      // under test.
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer((_) => Completer<AttendanceHistoryPage>().future);
    } else {
      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async =>
            AttendanceHistoryPage(rows: rows, monthTotals: monthTotals),
      );
    }

    final controller = AttendanceListController(repository: repository);

    // Both ends or neither, exactly as the screen sets them: a half-open range
    // is not a window the request can carry.
    if (rangeEnd != null) {
      controller.startDate.value =
          rangeStart ?? rangeEnd.subtract(const Duration(days: 30));
      controller.endDate.value = rangeEnd;
    }

    Get.put<AttendanceListController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id', 'ID')],
        theme: AppTheme.lightTheme,
        home: const AttendanceListView(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    return controller;
  }

  /// The one sentence the strip exposes to a screen reader.
  String? summaryOf(WidgetTester tester) {
    final finder = find.byType(AppDayStrip);

    if (finder.evaluate().isEmpty) return null;

    return tester.widget<AppDayStrip>(finder).summary;
  }

  group('it does not speak before it knows', () {
    testWidgets('a cold open shows a skeleton, not "7 tanpa catatan"', (
      tester,
    ) async {
      // The defect: the strip sits above the branch that handles loading, so it
      // used to render seven blank cells and assert an absence for every one of
      // them while the list below was still a skeleton.
      await pump(tester, rows: const [], loading: true);

      // No strip means no claim, and the skeleton holds the space in its place.
      expect(find.byType(AppDayStrip), findsNothing);
      expect(find.byType(AppSkeleton), findsWidgets);
      expect(find.textContaining('tanpa catatan'), findsNothing);
      expect(find.textContaining('Tujuh hari'), findsNothing);
    });

    testWidgets('a genuinely empty history draws no strip at all', (
      tester,
    ) async {
      // The empty state below already says there is nothing. Seven blank cells
      // above it are noise shaped like data.
      await pump(tester, rows: const [], loading: false);

      expect(find.byType(AppDayStrip), findsNothing);
    });
  });

  group('it counts each kind of day as itself', () {
    testWidgets('leave and sick days are NOT counted as attendance', (
      tester,
    ) async {
      // The old tally sent every tone that was not late or absent into "hadir",
      // and `PERMIT` / `SICK` / `HOLIDAY` map to the info tone — so a week of
      // sick leave read back as a week present.
      await pump(
        tester,
        rows: [
          row(back: 0, statusIn: 'ON_TIME', statusOut: 'ON_TIME'),
          row(back: 1, statusIn: 'SICK', statusOut: 'SICK'),
          row(back: 2, statusIn: 'PERMIT', statusOut: 'PERMIT'),
        ],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 hadir'));
      expect(summary, contains('2 izin'));
      expect(summary, isNot(contains('3 hadir')));
    });

    testWidgets('a real absence is told apart from a missing row', (
      tester,
    ) async {
      // Both used to increment one counter, so one genuine no-show plus two days
      // the page had not loaded read as "3 tanpa catatan" — a sentence that is
      // wrong about all three.
      await pump(
        tester,
        rows: [
          row(back: 0, statusIn: 'ABSENT', statusOut: 'ABSENT'),
          row(back: 1, statusIn: 'ON_TIME', statusOut: 'ON_TIME'),
        ],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 tidak hadir'));
      expect(summary, contains('5 tanpa catatan'));
      expect(summary, contains('1 hadir'));
    });

    testWidgets('lateness keeps its own word', (tester) async {
      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'LATE', statusOut: 'ON_TIME')],
      );

      expect(summaryOf(tester), contains('1 terlambat'));
    });

    testWidgets('a status this build cannot name is counted as nothing', (
      tester,
    ) async {
      // Guessed into the nearest bucket it would be a wrong number stated
      // confidently. The parts need not add to seven — this is a description,
      // not a ledger.
      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'SOMETHING_NEW', statusOut: 'ALSO_NEW')],
      );

      final summary = summaryOf(tester)!;

      expect(summary, isNot(contains('hadir')));
      expect(summary, contains('6 tanpa catatan'));
    });
  });

  group('a day with no shift is not called present', () {
    // `RecordAttendance::status()`:
    //
    //     $shift = $schedule?->timeWork;
    //     if ($shift === null) {
    //         return AttendanceStatus::Normal;
    //     }
    //
    // `Normal` there does not mean punctual — it means there was nothing to be
    // punctual against. Counting it as "hadir" turns a shrug into a fact.
    testWidgets('an unrostered clock-in counts as "tercatat"', (tester) async {
      await pump(
        tester,
        rows: [
          row(
            back: 0,
            statusIn: 'ON_TIME',
            statusOut: 'ON_TIME',
            rostered: false,
          ),
        ],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 tercatat'));
      expect(summary, isNot(contains('hadir')));
    });

    testWidgets('but sick leave keeps its word without a roster', (
      tester,
    ) async {
      // Only punctuality needs a shift. Sick, permit and absence are facts
      // about the day, and a missing roster does not make them less true.
      await pump(
        tester,
        rows: [
          row(back: 0, statusIn: 'SICK', statusOut: 'SICK', rostered: false),
          row(
            back: 1,
            statusIn: 'ABSENT',
            statusOut: 'ABSENT',
            rostered: false,
          ),
        ],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 izin'));
      expect(summary, contains('1 tidak hadir'));
    });

    testWidgets('"tercatat" and "tanpa catatan" are separate counts', (
      tester,
    ) async {
      // They used to draw the same grey cell, which made a recorded day and a
      // day with no row indistinguishable — the one distinction an employee
      // opens this screen to check.
      await pump(
        tester,
        rows: [
          row(
            back: 0,
            statusIn: 'ON_TIME',
            statusOut: 'ON_TIME',
            rostered: false,
          ),
        ],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 tercatat'));
      expect(summary, contains('6 tanpa catatan'));
    });
  });

  group('it describes the window it is actually looking at', () {
    testWidgets('with no filter it says the last seven days', (tester) async {
      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
      );

      expect(summaryOf(tester), startsWith('Tujuh hari terakhir'));
    });

    testWidgets('a filtered range moves the window and says so', (
      tester,
    ) async {
      // The strip promised "seven days" while reading whatever page one of a
      // filtered list happened to hold. Filter to an older month and every cell
      // went blank, with no hint that the window had moved.
      final DateTime end = DateTime(today.year, today.month, today.day - 30);

      await pump(
        tester,
        rows: [
          Attendance.fromJson({
            'id': 1,
            'date_presence': DateFormat('yyyy-MM-dd').format(end),
            'status_in': 'ON_TIME',
            'status_out': 'ON_TIME',
            'shift': 'Shift Pagi',
            'shift_in': '08:00:00',
            'shift_out': '17:00:00',
          }),
        ],
        rangeEnd: end,
      );

      final summary = summaryOf(tester)!;

      expect(summary, startsWith('Tujuh hari sampai'));
      expect(summary, contains('1 hadir'));
    });

    testWidgets('a filter running past today never draws unlived days', (
      tester,
    ) async {
      // A range ending at the end of the month should not paint the days that
      // have not happened yet as days with no record.
      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
        rangeEnd: DateTime(today.year, today.month, today.day + 20),
      );

      final summary = summaryOf(tester)!;

      expect(summary, startsWith('Tujuh hari terakhir'));
      expect(summary, contains('1 hadir'));
    });
  });

  group('it never draws a day the request did not ask for', () {
    testWidgets('a filter starting mid-window shortens the strip', (
      tester,
    ) async {
      // "Bulan ini" on the 3rd. The strip used to draw seven days back from
      // today regardless — four of them in the previous month, none of them
      // requested, all of them painted as days with no attendance. They had
      // rows; the screen had simply not been sent them.
      final DateTime start = DateTime(today.year, today.month, today.day - 2);

      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
        rangeStart: start,
        rangeEnd: today,
      );

      final strip = tester.widget<AppDayStrip>(find.byType(AppDayStrip));

      expect(strip.days, hasLength(3));
      expect(strip.summary, startsWith('3 hari terakhir'));
      // Two days without a row inside the window, and not one word about the
      // days outside it.
      expect(strip.summary, contains('2 tanpa catatan'));
    });

    testWidgets('a one-day filter draws one cell, not seven', (tester) async {
      final DateTime day = DateTime(today.year, today.month, today.day - 5);

      await pump(
        tester,
        rows: [row(back: 5, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
        rangeStart: day,
        rangeEnd: day,
      );

      final strip = tester.widget<AppDayStrip>(find.byType(AppDayStrip));

      expect(strip.days, hasLength(1));
      expect(strip.summary, contains('1 hadir'));
      expect(strip.summary, isNot(contains('tanpa catatan')));
    });
  });

  group('it anchors on the workspace clock', () {
    testWidgets("today's row lands inside the window", (tester) async {
      // `attendanceIsToday` uses `WorkspaceClock` precisely because the handset
      // crosses midnight at a different moment than the office that recorded the
      // row. The strip used `DateTime.now()` and could push today outside its
      // own seven days.
      await pump(
        tester,
        rows: [row(back: 0, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
      );

      final summary = summaryOf(tester)!;

      expect(summary, contains('1 hadir'));
      expect(summary, contains('6 tanpa catatan'));
    });

    testWidgets('a row older than the window is not counted', (tester) async {
      await pump(
        tester,
        rows: [row(back: 9, statusIn: 'ON_TIME', statusOut: 'ON_TIME')],
      );

      final summary = summaryOf(tester)!;

      expect(summary, isNot(contains('hadir')));
      expect(summary, contains('7 tanpa catatan'));
    });
  });

  group('the strip still draws seven cells', () {
    testWidgets('one per day, whatever the data', (tester) async {
      await pump(
        tester,
        rows: [row(back: 3, statusIn: 'ON_TIME', statusOut: 'LATE')],
      );

      expect(
        tester.widget<AppDayStrip>(find.byType(AppDayStrip)).days,
        hasLength(7),
      );
    });
  });
}
