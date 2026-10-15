import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required bool? registered,
    HomeTodayState state = HomeTodayState.unavailable,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TodayWorkCard(
              state: state,
              shiftName: null,
              scheduleIn: null,
              scheduleOut: null,
              timeIn: state == HomeTodayState.working ? '08:03' : null,
              timeOut: null,
              lateMinutes: null,
              nextPunch: AttendancePunch.clockOut,
              canClock: false,
              dayContext: null,
              error: AttendanceAccessException(isRegisteredDevice: registered),
              date: null,
              onClock: () {},
              onSignIn: () {},
              onHistory: () {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('known device denial shows the registration remedy', (
    tester,
  ) async {
    await pumpCard(tester, registered: false);

    expect(
      find.text('Perangkat belum terdaftar untuk absensi'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Gunakan perangkat yang terdaftar'),
      findsOneWidget,
    );
    expect(find.text('Absensi belum dapat dimuat'), findsNothing);
    expect(find.text('Coba lagi'), findsNothing);
    expect(find.text('Masuk kembali'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registered device without permission gets session guidance', (
    tester,
  ) async {
    await pumpCard(tester, registered: true);

    expect(find.text('Izin absensi sesi ini terbatas'), findsOneWidget);
    expect(find.textContaining('Hubungi administrator'), findsOneWidget);
    expect(find.textContaining('belum terdaftar'), findsNothing);
    expect(find.text('Coba lagi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old recorded time keeps its state and explains lost access', (
    tester,
  ) async {
    await pumpCard(tester, registered: false, state: HomeTodayState.working);

    expect(find.text('Sedang bekerja'), findsOneWidget);
    expect(find.text('08:03'), findsOneWidget);
    expect(
      find.textContaining('Gunakan perangkat yang terdaftar'),
      findsOneWidget,
    );
    expect(find.text('Absen pulang'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
