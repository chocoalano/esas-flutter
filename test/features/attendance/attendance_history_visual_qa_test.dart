@Tags(<String>['visual'])
library;

import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
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
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements AttendanceRepository {}

/// Riwayat absensi drawn to PNG, in the states worth looking at.
///
/// Diagnostic artefacts, not a CI gate. The file is tagged `visual` so
/// `flutter test` skips it — rasterisation differs between Flutter versions,
/// machines and installed fonts, and a byte comparison would fail for reasons
/// that have nothing to do with this screen.
///
/// ```
/// flutter test test/features/attendance/attendance_history_visual_qa_test.dart --update-goldens --run-skipped
/// ```
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockRepository repository;

  setUp(() => repository = _MockRepository());

  tearDown(Get.reset);

  /// Satu hari yang masuk akal: jam masuk yang bergeser sedikit tiap hari,
  /// jam pulang sore, dan jadwal seperti yang dikirim server.
  Attendance day(
    int index, {
    String statusIn = 'NORMAL',
    String statusOut = 'NORMAL',
    bool open = false,
    bool rostered = true,
    String? dayType,
  }) {
    String clock(int hour, int minute) =>
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';

    return Attendance.fromJson({
      'id': index,
      'date_presence': '2026-09-${index.toString().padLeft(2, '0')}',
      'time_in': clock(index.isEven ? 8 : 7, (index * 11) % 60),
      'time_out': open ? null : clock(17, (index * 7) % 60),
      'status_in': statusIn,
      'status_out': statusOut,
      'type_in': 'FACE',
      'type_out': 'QR',
      if (dayType != null) 'day_type': dayType,
      if (rostered) ...{
        'shift': 'Shift Pagi',
        'shift_in': '08:00:00',
        'shift_out': '17:00:00',
      },
    });
  }

  Future<void> render(
    WidgetTester tester,
    String name, {
    required List<Attendance> rows,
    Size size = const Size(390, 844),
    ThemeData? theme,
    double textScale = 1.0,
    bool loading = false,
    ApiException? error,
    void Function(AttendanceListController)? after,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    when(
      () => repository.history(
        page: any(named: 'page'),
        perPage: any(named: 'perPage'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) {
      if (loading) return Completer<AttendanceHistoryPage>().future;
      if (error != null) return Future<AttendanceHistoryPage>.error(error);

      return Future<AttendanceHistoryPage>.value(
        AttendanceHistoryPage(
          rows: rows,
          monthTotals: rows.isEmpty
              ? const <AttendanceMonthTotals>[]
              : <AttendanceMonthTotals>[
                  AttendanceMonthTotals(
                    month: DateTime(2026, 9),
                    recordedDays: rows.length,
                    lateDays: 2,
                    averageClockIn: '07:41',
                  ),
                ],
        ),
      );
    });

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
        theme: theme ?? AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AttendanceListView(),
      ),
    );

    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    after?.call(controller);

    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await expectLater(
      find.byType(AttendanceListView),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  /// One row per state worth looking at, in the order the report lists them.
  List<Attendance> month() => [
    // A — rostered and punctual.
    day(1),
    // C — late arrival.
    day(2, statusIn: 'LATE'),
    // F — excused by an administrator.
    day(3, statusIn: 'UNLATE'),
    // D — early departure.
    day(4, statusOut: 'LATE'),
    // E — both, which is the one badge that counts rather than names.
    day(5, statusIn: 'LATE', statusOut: 'LATE'),
    // G — a past day nobody closed.
    day(6, open: true),
    // H — a holiday somebody worked anyway.
    day(7, dayType: 'holiday', rostered: false),
    // B — clocked with no roster to be punctual against.
    day(8, rostered: false),
  ];

  testWidgets('A — ledger, terang', (tester) async {
    await render(tester, 'history_a_ledger', rows: month());
  });

  testWidgets('B — ledger, gelap', (tester) async {
    await render(
      tester,
      'history_b_dark',
      rows: month(),
      theme: AppTheme.darkTheme,
    );
  });

  testWidgets('C — riwayat kosong', (tester) async {
    await render(tester, 'history_c_empty', rows: const []);
  });

  testWidgets('D — periode kosong', (tester) async {
    await render(
      tester,
      'history_d_filtered_empty',
      rows: const [],
      after: (controller) => controller.applyDateRange(
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 21),
      ),
    );
  });

  testWidgets('E — halaman pertama gagal', (tester) async {
    await render(
      tester,
      'history_e_error',
      rows: const [],
      error: const ApiException('Tidak ada koneksi internet.'),
    );
  });

  testWidgets('F — sedang memuat', (tester) async {
    await render(tester, 'history_f_loading', rows: const [], loading: true);
  });

  testWidgets('G — 320dp, skala teks 1,5', (tester) async {
    await render(
      tester,
      'history_g_320_x15',
      rows: month(),
      size: const Size(320, 800),
      textScale: 1.5,
    );
  });
}
