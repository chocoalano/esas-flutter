import 'dart:async';

import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_badge.dart';
import 'package:esas/core/ui/components/app_sparkline.dart';
import 'package:esas/features/attendance/data/models/attendance.dart';
import 'package:esas/features/attendance/data/models/attendance_history_page.dart';
import 'package:esas/features/attendance/data/models/attendance_month_totals.dart';
import 'package:esas/features/attendance/data/repositories/attendance_repository.dart';
import 'package:esas/features/attendance/presentation/attendance_labels.dart';
import 'package:esas/features/attendance/presentation/controllers/attendance_list_controller.dart';
import 'package:esas/features/attendance/presentation/views/attendance_list_view.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_detail_sheet.dart';
import 'package:esas/features/attendance/presentation/widgets/attendance_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

/// The attendance history screen, and the line between what it knows and what
/// it says.
///
/// Almost every test here is a variation on one question. The server sends
/// `status_in: "normal"` for two completely different situations — a punch
/// measured against a shift and found punctual, and a punch on a day that had
/// no shift at all:
///
/// ```php
/// // RecordAttendance::status()
/// $shift = $schedule?->timeWork;
/// if ($shift === null) {
///     return AttendanceStatus::Normal;
/// }
/// ```
///
/// The screen used to print "Tepat waktu" for both, because the model threw the
/// roster away: it read a `schedule` key the API has never sent while `shift`,
/// `shift_in`, `shift_out` and `day_type` arrived on every row and went
/// straight in the bin.

/// The month the fixtures live in.
final DateTime _september = DateTime(2026, 9);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Attendance parse(Map<String, dynamic> json) => Attendance.fromJson(json);

  group('the row parses the roster the API has been sending all along', () {
    test('shift, its window, and the kind of day', () {
      final row = parse({
        'id': 1,
        'date_presence': '2026-09-01',
        'time_in': '08:11:00',
        'time_out': '17:32:00',
        'shift': 'Shift Pagi',
        'shift_in': '08:00:00',
        'shift_out': '17:00:00',
        'day_type': 'working',
      });

      expect(row.shift, 'Shift Pagi');
      expect(row.shiftIn, '08:00:00');
      expect(row.shiftOut, '17:00:00');
      expect(row.dayType, 'working');
      expect(row.hasSchedule, isTrue);
      expect(row.crossesMidnight, isFalse);
    });

    test('a payload without a roster is not pretended into one', () {
      final row = parse({'id': 1, 'date_presence': '2026-09-01'});

      expect(row.shift, isNull);
      expect(row.hasSchedule, isFalse);
      expect(row.crossesMidnight, isFalse);
    });

    test('a night shift is recognised as crossing midnight', () {
      final row = parse({
        'id': 1,
        'shift_in': '22:00:00',
        'shift_out': '06:00:00',
      });

      expect(row.crossesMidnight, isTrue);
    });
  });

  group('a status is said only as strongly as the roster supports', () {
    test('"normal" with a shift is punctuality', () {
      expect(
        attendanceStatusLabelFor('NORMAL', hasSchedule: true),
        'Tepat waktu',
      );
      expect(
        attendanceStatusToneFor('NORMAL', hasSchedule: true),
        AppBadgeTone.success,
      );
    });

    test('"normal" without one is only a record', () {
      expect(
        attendanceStatusLabelFor('NORMAL', hasSchedule: false),
        'Tercatat',
      );
      expect(
        attendanceStatusToneFor('NORMAL', hasSchedule: false),
        AppBadgeTone.neutral,
      );
    });

    test('sick and permit keep their word with or without a roster', () {
      // Only punctuality needs a shift to be measured against.
      expect(attendanceStatusLabelFor('SICK', hasSchedule: false), 'Sakit');
      expect(
        attendanceStatusToneFor('SICK', hasSchedule: false),
        AppBadgeTone.info,
      );
      expect(
        attendanceStatusLabelFor('ABSENT', hasSchedule: false),
        'Tidak hadir',
      );
    });

    test('an early departure is not called arriving late', () {
      // The server marks both with AttendanceStatus::Late.
      expect(
        attendanceOutStatusLabelFor('LATE', hasSchedule: true),
        'Pulang awal',
      );
    });

    test('an excused day says only what the domain says', () {
      // UNLATE has been in the enum all along and used to render as "Tidak
      // diketahui". It is also produced by no code path whatsoever — an
      // administrator sets it on the attendance form and nothing else can — so
      // the label stops at "excused" rather than asserting a lateness that was
      // then forgiven.
      expect(
        attendanceStatusLabelFor('UNLATE', hasSchedule: true),
        'Dimaafkan',
      );
      expect(
        attendanceStatusToneFor('UNLATE', hasSchedule: true),
        AppBadgeTone.success,
      );
    });
  });

  // The circular mean itself is pinned server-side now, where the metric lives:
  // see `AttendanceHistoryQueryCountTest` and the summary tests in
  // `SelfServiceAttendanceHistoryTest` for the 23:55/00:05 case and the
  // non-clustering case. Two implementations of "usual arrival time" is two
  // answers, and this screen no longer holds one of them.

  group('the shift line', () {
    test('names the shift and its window', () {
      expect(
        attendanceShiftLine(
          shift: 'Shift Pagi',
          shiftIn: '08:00:00',
          shiftOut: '17:00:00',
        ),
        'Shift Pagi · 08:00–17:00',
      );
    });

    test('is null when there is no roster to describe', () {
      expect(
        attendanceShiftLine(shift: null, shiftIn: null, shiftOut: null),
        isNull,
      );
    });
  });

  group('the ledger row', () {
    Future<void> pumpRow(WidgetTester tester, Attendance attendance) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AttendanceListItem(attendance: attendance, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('labels both punches and states the duration', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:11:00',
          'time_out': '17:32:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      // The arrow told the reader nothing about which clock was which.
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Pulang'), findsOneWidget);
      expect(find.text('08:11'), findsOneWidget);
      expect(find.text('17:32'), findsOneWidget);
      expect(find.text('Durasi'), findsOneWidget);
      expect(find.text('9j 21m'), findsOneWidget);
    });

    testWidgets('shows the shift the status was measured against', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:11:00',
          'time_out': '17:32:00',
          'status_in': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Shift Pagi · 08:00–17:00'), findsOneWidget);
      expect(find.text('Tepat waktu'), findsOneWidget);
    });

    testWidgets('will not call an unrostered day punctual', (tester) async {
      // 15:14 → 15:16 on a day with no shift. The old row said "Tepat waktu".
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '15:14:00',
          'time_out': '15:16:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
        }),
      );

      expect(find.text('Tepat waktu'), findsNothing);
      expect(find.text('Tercatat'), findsOneWidget);
    });

    testWidgets('the badge names the punch that decided its colour', (
      tester,
    ) async {
      // Tone came from both punches, the word from the clock-in only — so this
      // day used to read "Tepat waktu" in warning yellow.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '15:00:00',
          'status_in': 'NORMAL',
          'status_out': 'LATE',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Pulang awal'), findsOneWidget);
      expect(find.text('Tepat waktu'), findsNothing);
    });

    testWidgets('a rest day says so', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-06',
          'time_in': '09:00:00',
          'status_in': 'NORMAL',
          'day_type': 'rest',
        }),
      );

      expect(find.textContaining('Hari libur'), findsOneWidget);
    });

    testWidgets('no duration is invented from a single punch', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'status_in': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Durasi'), findsNothing);
      expect(find.text('--:--'), findsOneWidget);
    });
  });

  group('the row degrades rather than inventing', () {
    Future<void> pumpRow(WidgetTester tester, Attendance attendance) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AttendanceListItem(attendance: attendance, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('reversed clocks on a day shift produce no duration', (
      tester,
    ) async {
      // 15:00 in, 09:00 out. The old rule added a day to every reversed pair,
      // so a mistyped correction became a confident "18j 00m" on the row
      // somebody had opened the screen to question.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '15:00:00',
          'time_out': '09:00:00',
          'status_in': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Durasi'), findsNothing);
      expect(find.text('18j 00m'), findsNothing);
    });

    testWidgets('but a night shift crossing midnight still counts', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '22:00:00',
          'time_out': '06:00:00',
          'status_in': 'NORMAL',
          'shift': 'Shift Malam',
          'shift_in': '22:00:00',
          'shift_out': '06:00:00',
        }),
      );

      expect(find.text('8j 00m'), findsOneWidget);
    });

    testWidgets('a clock-out with no clock-in is not a negative day', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_out': '17:00:00',
          'status_out': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Durasi'), findsNothing);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('a late arrival AND an early departure keeps both meanings', (
      tester,
    ) async {
      // Both punches carry `late`, and picking one used to silently drop the
      // other: the row read "Terlambat" and nothing on it said the person had
      // also gone home two hours early.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:30:00',
          'time_out': '15:00:00',
          'status_in': 'LATE',
          'status_out': 'LATE',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      // One badge, because two on a ledger row is where a list stops being
      // scannable — and a line underneath that spells out what it counted.
      expect(find.text('2 catatan'), findsOneWidget);
      expect(find.text('Terlambat masuk · Pulang awal'), findsOneWidget);
    });

    testWidgets('one problem stays one badge, with no supporting line', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:30:00',
          'time_out': '17:00:00',
          'status_in': 'LATE',
          'status_out': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('2 catatan'), findsNothing);
      expect(find.textContaining('Terlambat masuk'), findsNothing);
    });

    testWidgets('attendance on a holiday is shown, not hidden', (tester) async {
      // `day_type` describes the company calendar, not whether this person
      // worked. Somebody who clocked on Idul Fitri has a record, and hiding it
      // would hide the day most likely to be paid differently.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'day_type': 'holiday',
        }),
      );

      expect(find.textContaining('Hari besar'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('17:00'), findsOneWidget);
    });

    testWidgets('a payload with no roster fields at all still renders', (
      tester,
    ) async {
      // A deployment predating `shift` / `day_type`. Every new field is
      // optional, and none of them may be the reason a row fails to draw.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
        }),
      );

      expect(find.text('Tercatat'), findsOneWidget);
      expect(find.text('9j 00m'), findsOneWidget);
    });
  });

  group('the day is a badge, and every row carries a status', () {
    Future<void> pumpRow(WidgetTester tester, Attendance attendance) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AttendanceListItem(attendance: attendance, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the weekday is its own label, said once', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-04',
          'time_in': '07:58:00',
          'time_out': '17:03:00',
          'status_in': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      // 2026-09-04 is a Friday. The badge carries the day; the text beside it
      // carries the date, and neither repeats the other.
      expect(find.text('JUM'), findsOneWidget);
      expect(find.text('4 Sep 2026'), findsOneWidget);
      expect(find.text('Jum, 4 Sep 2026'), findsNothing);
    });

    testWidgets('a Sunday is not painted as a holiday on the name alone', (
      tester,
    ) async {
      // 2026-09-06 is a Sunday, and `day_type` says the company worked it.
      // Whether a date is a rest day is `WorkCalendar`'s answer, not the
      // weekday's — a six-day working week is ordinary here.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-06',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'day_type': 'working',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(find.text('MIN'), findsOneWidget);
      expect(find.textContaining('Hari libur'), findsNothing);
      expect(find.text('Tepat waktu'), findsOneWidget);
    });

    testWidgets('every state has a status word, never colour alone', (
      tester,
    ) async {
      final cases = <Map<String, dynamic>, String>{
        // A — rostered and punctual.
        {
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }: 'Tepat waktu',
        // B — clocked, but nothing to be punctual against.
        {
          'date_presence': '2026-09-01',
          'time_in': '09:59:00',
          'time_out': '13:29:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
        }: 'Tercatat',
        // C — late arrival.
        {
          'date_presence': '2026-09-01',
          'time_in': '08:30:00',
          'time_out': '17:00:00',
          'status_in': 'LATE',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }: 'Terlambat',
        // D — early departure, which the server also calls `late`.
        {
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '15:00:00',
          'status_in': 'NORMAL',
          'status_out': 'LATE',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }: 'Pulang awal',
        // F — excused by an administrator.
        {
          'date_presence': '2026-09-01',
          'time_in': '08:30:00',
          'time_out': '17:00:00',
          'status_in': 'UNLATE',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }: 'Dimaafkan',
        // G — a past day nobody closed.
        {
          'date_presence': '2026-09-01',
          'time_in': '08:02:00',
          'status_in': 'NORMAL',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }: 'Belum lengkap',
        // Leave keeps its own word with or without a roster.
        {
          'date_presence': '2026-09-01',
          'status_in': 'SICK',
          'status_out': 'SICK',
        }: 'Sakit',
      };

      for (final entry in cases.entries) {
        await pumpRow(tester, parse(entry.key));

        // Not a dot, not a border, not an icon. A word.
        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: 'expected the badge to read "${entry.value}"',
        );
      }
    });

    testWidgets('a holiday with attendance keeps both facts', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-06',
          'time_in': '09:00:00',
          'time_out': '12:00:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
          'day_type': 'holiday',
        }),
      );

      // The row is not hidden because the calendar called the day a holiday —
      // that is the day most likely to be paid differently.
      expect(find.text('MIN'), findsOneWidget);
      expect(find.textContaining('Hari besar'), findsOneWidget);
      expect(find.text('Tercatat'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('the whole row reads as one sentence', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-04',
          'time_in': '07:58:00',
          'time_out': '17:03:00',
          'status_in': 'NORMAL',
          'status_out': 'NORMAL',
          'shift': 'Shift Pagi',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      final SemanticsNode node = tester.getSemantics(
        find.byType(AttendanceListItem),
      );

      expect(node.label, contains('Jumat, 4 September 2026'));
      expect(node.label, contains('Status tepat waktu'));
      expect(node.label, contains('Masuk 07:58'));
      expect(node.label, contains('Pulang 17:03'));
    });

    testWidgets('a narrow screen at large type reflows instead of clipping', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: AttendanceListItem(
                attendance: parse({
                  'date_presence': '2026-09-04',
                  'time_in': '08:30:00',
                  'time_out': '17:00:00',
                  'status_in': 'UNLATE',
                  'shift': 'Shift Pagi',
                  'shift_in': '08:00:00',
                  'shift_out': '17:00:00',
                }),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The longest label in the vocabulary, at the smallest supported width.
      // It may wrap onto its own line; it may not be shrunk or clipped.
      expect(find.text('Dimaafkan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('legacy and corrupt rows degrade instead of inventing', () {
    Future<void> pumpRow(WidgetTester tester, Attendance attendance) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: AttendanceListItem(attendance: attendance, onTap: () {}),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a clock-out with no clock-in still draws', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_out': '17:00:00',
          'status_out': 'NORMAL',
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('17:00'), findsOneWidget);
      expect(find.text('Durasi'), findsNothing);
    });

    testWidgets('an unparseable time is blank, not zero', (tester) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': 'not-a-time',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
        }),
      );

      expect(tester.takeException(), isNull);
      // Never "00:00", which is a real clock-in at midnight.
      expect(find.text('00:00'), findsNothing);
      expect(find.text('Durasi'), findsNothing);
    });

    testWidgets('a day type this build does not know is simply not shown', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'day_type': 'something_new',
        }),
      );

      expect(tester.takeException(), isNull);
      // Not echoed raw: a server enum on screen is an enum becoming an
      // interface.
      expect(find.textContaining('something_new'), findsNothing);
      expect(find.text('Tercatat'), findsOneWidget);
    });

    testWidgets('a shift start with no end still reads sensibly', (
      tester,
    ) async {
      // `shift_in` without `shift_out`. There is a start to be measured
      // against, so the status may speak; there is no window to print.
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'NORMAL',
          'shift_in': '08:00:00',
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('--:--'), findsNothing);
    });

    testWidgets('a shift end with no start claims no schedule', (tester) async {
      final row = parse({
        'date_presence': '2026-09-01',
        'time_in': '08:00:00',
        'time_out': '17:00:00',
        'status_in': 'NORMAL',
        'shift_out': '17:00:00',
      });

      // `hasSchedule` reads the START, because that is what a clock-in is
      // measured against. Without it, "Tepat waktu" has no referent.
      expect(row.hasSchedule, isFalse);

      await pumpRow(tester, row);

      expect(find.text('Tercatat'), findsOneWidget);
      expect(find.text('Tepat waktu'), findsNothing);
    });

    testWidgets('an unknown status is not guessed into a verdict', (
      tester,
    ) async {
      await pumpRow(
        tester,
        parse({
          'date_presence': '2026-09-01',
          'time_in': '08:00:00',
          'time_out': '17:00:00',
          'status_in': 'HALF_DAY',
          'shift_in': '08:00:00',
          'shift_out': '17:00:00',
        }),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('HALF_DAY'), findsNothing);
    });
  });

  group('the detail sheet keeps every fact the row summarised', () {
    testWidgets('late arrival and early departure both survive the drill-in', (
      tester,
    ) async {
      final attendance = parse({
        'date_presence': '2026-09-01',
        'time_in': '08:30:00',
        'time_out': '15:00:00',
        'status_in': 'LATE',
        'status_out': 'LATE',
        'shift': 'Shift Pagi',
        'shift_in': '08:00:00',
        'shift_out': '17:00:00',
      });

      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => AttendanceListItem(
                attendance: attendance,
                onTap: () => showAttendanceDetailSheet(context, attendance),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('2 catatan'), findsOneWidget);

      await tester.tap(find.byType(AttendanceListItem));
      await tester.pumpAndSettle();

      // The sheet is allowed to be MORE specific than the row. It is not
      // allowed to drop half of what the row counted.
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('Pulang awal'), findsOneWidget);
    });
  });

  group('the capture method is named as the server names it', () {
    // `AttendanceMethod` has exactly three values. The client used to map four
    // it never sends and miss two of the three it does.
    test('every value the enum can hold has a word', () {
      expect(attendanceMethodLabel('qrcode'), 'Pindai QR');
      expect(attendanceMethodLabel('face-device'), 'Pindai wajah');
      expect(
        attendanceMethodLabel('face-geolocation'),
        'Pindai wajah + lokasi',
      );
      expect(attendanceMethodLabel(null), attendanceEmptyValue);
      expect(attendanceMethodLabel('something-new'), 'Metode lain');
    });
  });

  group('the list and the detail say the same thing', () {
    testWidgets('an unrostered day is "Tercatat" in both', (tester) async {
      final attendance = parse({
        'date_presence': '2026-09-01',
        'time_in': '15:14:00',
        'time_out': '15:16:00',
        'status_in': 'NORMAL',
        'status_out': 'NORMAL',
      });

      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => AttendanceListItem(
                attendance: attendance,
                onTap: () => showAttendanceDetailSheet(context, attendance),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tercatat'), findsOneWidget);

      await tester.tap(find.byType(AttendanceListItem));
      await tester.pumpAndSettle();

      // Both punches, both schedule-aware. A list that says "Tercatat" above a
      // sheet that says "Tepat waktu" is a screen arguing with itself.
      expect(find.text('Tepat waktu'), findsNothing);
      expect(find.text('Tercatat'), findsNWidgets(3));
    });
  });

  group('the screen', () {
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

    Future<AttendanceListController> pump(
      WidgetTester tester, {
      required List<Attendance> rows,
      List<AttendanceMonthTotals>? monthTotals,
      bool loading = false,
    }) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) => loading
            ? Completer<AttendanceHistoryPage>().future
            : Future<AttendanceHistoryPage>.value(
                AttendanceHistoryPage(rows: rows, monthTotals: monthTotals),
              ),
      );

      final controller = AttendanceListController(repository: repository);
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

    Attendance day(int index, {String status = 'NORMAL'}) => parse({
      'id': index,
      'date_presence': '2026-09-${index.toString().padLeft(2, '0')}',
      'time_in': '08:${index.toString().padLeft(2, '0')}:00',
      'time_out': '17:00:00',
      'status_in': status,
      'status_out': 'NORMAL',
      'shift': 'Shift Pagi',
      'shift_in': '08:00:00',
      'shift_out': '17:00:00',
    });

    testWidgets('an unfiltered empty history does not blame a filter', (
      tester,
    ) async {
      // It used to say "pada rentang tanggal ini" and offer to change a range
      // that was never set.
      await pump(tester, rows: const []);

      expect(find.text('Belum ada absensi tercatat'), findsOneWidget);
      expect(find.text('Tampilkan semua tanggal'), findsNothing);
    });

    testWidgets('a filtered empty history offers the way out', (tester) async {
      final controller = await pump(tester, rows: const []);

      await controller.applyDateRange(
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
      );
      await tester.pump();

      expect(find.text('Tidak ada absensi pada periode ini'), findsOneWidget);
      expect(find.text('Tampilkan semua tanggal'), findsOneWidget);
    });

    testWidgets('the period names the window the request actually carries', (
      tester,
    ) async {
      // It used to read "Semua tanggal tercatat" while the client sent no
      // `from`/`to` at all — and the endpoint answers an unspecified window
      // with THE CURRENT MONTH. On the 3rd of a month the caption claimed
      // everything and the screen held three days.
      final controller = await pump(tester, rows: const []);

      expect(find.text('Periode'), findsOneWidget);
      expect(find.text('Semua tanggal tercatat'), findsNothing);

      final range = controller.effectiveRange;
      expect(range.end.difference(range.start).inDays, 364);

      // The work the fake affordance seemed to offer belongs to a chip, named
      // for what it does rather than for what it cannot do.
      expect(find.text('12 bulan'), findsOneWidget);
    });

    testWidgets('an unfiltered request still declares both ends', (
      tester,
    ) async {
      await pump(tester, rows: const []);

      final captured = verify(
        () => repository.history(
          page: any(named: 'page'),
          perPage: any(named: 'perPage'),
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
        ),
      ).captured;

      // Never null. A half-open request is a request whose window the server
      // chooses and the screen does not know.
      expect(captured[0], isNotNull);
      expect(captured[1], isNotNull);
    });

    testWidgets('the custom chip names the range it applied', (tester) async {
      final controller = await pump(tester, rows: const []);

      await controller.applyDateRange(
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 21),
      );
      await tester.pump();

      // Previously the chip lit up and still read "Pilih tanggal".
      expect(find.text('Pilih tanggal'), findsNothing);
      expect(find.text('3 – 21 Agu 2026'), findsWidgets);
    });

    testWidgets('clearing the filter is one tap', (tester) async {
      final controller = await pump(tester, rows: const []);

      await controller.applyDateRange(
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 21),
      );
      await tester.pump();

      await tester.tap(find.text('12 bulan'));
      await tester.pumpAndSettle();

      expect(controller.startDate.value, isNull);
      expect(controller.endDate.value, isNull);
    });

    testWidgets('the month header leads with the server\'s figures', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [
          day(1),
          day(2),
          day(3, status: 'LATE'),
        ],
        monthTotals: [
          AttendanceMonthTotals(
            month: _september,
            recordedDays: 22,
            lateDays: 4,
            averageClockIn: '06:47',
          ),
        ],
      );

      expect(find.text('September 2026'), findsOneWidget);
      // Sentence case: a month is a label, not an announcement.
      expect(find.text('SEPTEMBER 2026'), findsNothing);

      // Twenty-two and four, from the window — not three and one, from the page
      // in hand. This is the whole point of the summary contract.
      expect(find.text('22'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('06:47'), findsOneWidget);
      expect(find.text('Hari tercatat'), findsOneWidget);
      expect(find.text('Rata-rata masuk'), findsOneWidget);
    });

    testWidgets('no server figures means no figures at all', (tester) async {
      // A deployment that predates `summary`. Counting the loaded rows instead
      // would put "3 hari tercatat" under a heading that says September.
      await pump(tester, rows: [day(1), day(2), day(3)]);

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Hari tercatat'), findsNothing);
      expect(find.byType(AppSparkline), findsNothing);
    });

    testWidgets('the trend waits until the month is all here', (tester) async {
      // Four points, but the server says the month holds twenty-two days. A
      // line through page one under the words "September 2026" is a shape
      // describing something else.
      await pump(
        tester,
        rows: [day(1), day(2), day(3), day(4)],
        monthTotals: [
          AttendanceMonthTotals(
            month: _september,
            recordedDays: 22,
            lateDays: 0,
            averageClockIn: '08:03',
          ),
        ],
      );

      expect(find.byType(AppSparkline), findsNothing);
    });

    testWidgets('and draws once they are', (tester) async {
      await pump(
        tester,
        rows: [day(1), day(2), day(3), day(4)],
        monthTotals: [
          AttendanceMonthTotals(
            month: _september,
            recordedDays: 4,
            lateDays: 0,
            averageClockIn: '08:03',
          ),
        ],
      );

      expect(find.byType(AppSparkline), findsOneWidget);
    });

    testWidgets('three points are never a trend, complete or not', (
      tester,
    ) async {
      await pump(
        tester,
        rows: [day(1), day(2), day(3)],
        monthTotals: [
          AttendanceMonthTotals(
            month: _september,
            recordedDays: 3,
            lateDays: 0,
            averageClockIn: '08:03',
          ),
        ],
      );

      expect(find.byType(AppSparkline), findsNothing);
    });
  });
}
