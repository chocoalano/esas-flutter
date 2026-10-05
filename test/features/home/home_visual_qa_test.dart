@Tags(<String>['visual'])
library;

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/routes/home_pages.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

/// Beranda UTUH, digambar dari pohon produksi ke dalam berkas PNG.
///
/// Ini bukan uji perilaku dan tidak menegaskan apa pun tentang teks. Gunanya
/// satu: separuh bawah Beranda berada di bawah lipatan pada setiap ponsel, dan
/// simulator tidak bisa digulir dari baris perintah — sehingga selama empat
/// gelombang tidak ada satu pun cara untuk MELIHAT bagaimana Aktivitas terbaru,
/// Ringkasan bulan ini, dan Sisa cuti duduk bersama.
///
/// Viewport-nya yang diperpanjang, bukan tata letaknya. Halaman digambar pada
/// lebar ponsel sungguhan (390 atau 360) dengan tinggi yang dilebihkan sampai
/// seluruh isinya muat, jadi yang terlihat di PNG adalah komposisi yang sama
/// dengan yang digulir orang — hanya seluruhnya sekaligus.
///
/// Jalankan dengan:
///
/// ```
/// flutter test test/features/home/home_visual_qa_test.dart --update-goldens
/// ```
///
/// Berkasnya artefak diagnostik, bukan baseline yang menggagalkan CI: berkas
/// ini bertanda `visual` sehingga `flutter test --exclude-tags visual`
/// melewatinya, dan tidak ada satu pun keputusan produk yang bergantung pada
/// kesamaan piksel antar mesin.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockHomeRepository repository;

  final List<Announcement> announcements = <Announcement>[
    Announcement(
      id: 1,
      title: 'KEBIJAKAN JAM MASUK KERJA, IJIN TERLAMBAT DAN PULANG AWAL',
      publishedBy: 'TUBAGUS ANGGA DHEVIESTS',
      excerpt: '&nbsp;BERIKUT LINK YANG BISA DI AKSES UNTUK SELURUH KARYAWAN.',
      createdAt: DateTime(2025, 7, 3),
    ),
    Announcement(
      id: 2,
      title: 'Libur bersama Idul Fitri',
      publishedBy: 'Departemen SDM',
      createdAt: DateTime(2025, 6, 20),
    ),
    Announcement(id: 3, title: 'Perubahan jam kerja', publishedBy: 'HRD'),
  ];

  List<Permit> permits() => <Permit>[
    Permit.fromJson(<String, dynamic>{
      'id': 1,
      'permit_numbers': 'PRM-2026-0000012',
      'start_date': '2026-09-02',
      'permit_type': <String, dynamic>{'id': 1, 'name': 'Izin sakit'},
      'approvals': <dynamic>[],
    }),
    Permit.fromJson(<String, dynamic>{
      'id': 2,
      'permit_numbers': 'PRM-2026-0000009',
      'start_date': '2026-09-01',
      'permit_type': <String, dynamic>{'id': 2, 'name': 'Penyesuaian jam'},
      // `resolvePermitStatus` membaca `user_approve`, BUKAN `status`. Fixture
      // pertama berkas ini memakai `status`, dan hasilnya kedua baris tergambar
      // amber "Diproses" — bukan bug produksi melainkan fixture yang menutupi
      // apakah pemetaan warnanya benar.
      'approvals': <dynamic>[
        <String, dynamic>{'id': 1, 'user_approve': 'y', 'user_id': 3},
      ],
    }),
    Permit.fromJson(<String, dynamic>{
      'id': 3,
      'permit_numbers': 'PRM-2026-0000004',
      'start_date': '2026-08-29',
      'permit_type': <String, dynamic>{'id': 3, 'name': 'Cuti tahunan'},
      'approvals': <dynamic>[
        <String, dynamic>{'id': 2, 'user_approve': 'n', 'user_id': 3},
      ],
    }),
  ];

  setUp(() {
    repository = _MockHomeRepository();
    when(() => repository.userName).thenReturn('ALAN GENTINA');
    when(() => repository.userAvatar).thenReturn('');
    when(() => repository.unreadNotifications).thenReturn(null);
  });

  tearDown(Get.reset);

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Size size,
    double textScale = 1.0,
    Object? attendanceThrows,
    DashboardTimes? times,
    List<Announcement> notices = const <Announcement>[],
    List<Permit> activity = const <Permit>[],
    MonthSummary? summary,
    List<LeaveBalance> leave = const <LeaveBalance>[],
  }) async {
    if (attendanceThrows != null) {
      when(() => repository.todayAttendance()).thenThrow(attendanceThrows);
    } else {
      when(
        () => repository.todayAttendance(),
      ).thenAnswer((_) async => times ?? const DashboardTimes());
    }

    when(
      () => repository.activeAnnouncements(),
    ).thenAnswer((_) async => notices);
    when(
      () => repository.recentPermits(limit: any(named: 'limit')),
    ).thenAnswer((_) async => activity);
    when(
      () => repository.monthSummary(refresh: any(named: 'refresh')),
    ).thenAnswer(
      (_) async => summary ?? const MonthSummary(workedDays: 0, lateCount: 0),
    );
    when(
      () => repository.leaveBalances(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => leave);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Get.put<HomeRepository>(repository);
    Get.put<BottomNavController>(
      BottomNavController(
        destinations: const <String>[
          HomeRoutes.home,
          AttendanceRoutes.attendance,
          PermitRoutes.permit,
          NotificationRoutes.notification,
          ProfileRoutes.profile,
        ],
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: GetMaterialApp(
          locale: const Locale('id', 'ID'),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('id', 'ID')],
          theme: AppTheme.lightTheme,
          initialRoute: HomeRoutes.home,
          getPages: HomePages.pages,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('A — runtime saat ini: absensi 403, bawah kosong', (
    tester,
  ) async {
    await render(
      tester,
      name: 'home_a_runtime',
      size: const Size(390, 1800),
      attendanceThrows: const ApiException('Ditolak.', status: 403),
      notices: announcements,
    );
  });

  testWidgets('B — data lengkap', (tester) async {
    await render(
      tester,
      name: 'home_b_rich',
      size: const Size(390, 2200),
      times: const DashboardTimes(
        timeIn: '08:11',
        scheduleIn: '08:00',
        scheduleOut: '17:00',
        scheduleName: 'Shift Pagi',
        nextPresence: 'out',
        attendanceEnabled: true,
      ),
      notices: announcements,
      activity: permits(),
      summary: const MonthSummary(workedDays: 12, lateCount: 1),
      leave: const <LeaveBalance>[
        LeaveBalance(
          code: 'ANNUAL',
          label: 'Cuti tahunan',
          remaining: 8,
          quota: 12,
        ),
        LeaveBalance(code: 'SPECIAL', label: 'Cuti khusus', remaining: 2),
      ],
    );
  });

  testWidgets('C — sebagian: aktivitas kosong, bulanan berisi', (tester) async {
    await render(
      tester,
      name: 'home_c_partial',
      size: const Size(390, 1900),
      times: const DashboardTimes(
        scheduleIn: '08:00',
        scheduleOut: '17:00',
        scheduleName: 'Shift Pagi',
        nextPresence: 'in',
      ),
      notices: announcements,
      summary: const MonthSummary(workedDays: 18, lateCount: 0),
    );
  });

  testWidgets('D — layar kecil, teks besar', (tester) async {
    await render(
      tester,
      name: 'home_d_small',
      size: const Size(360, 2600),
      textScale: 1.3,
      times: const DashboardTimes(
        timeIn: '08:11',
        scheduleIn: '08:00',
        scheduleOut: '17:00',
        scheduleName: 'Shift Pagi',
        nextPresence: 'out',
      ),
      notices: announcements,
      activity: permits(),
      summary: const MonthSummary(workedDays: 12, lateCount: 1),
      leave: const <LeaveBalance>[
        LeaveBalance(
          code: 'ANNUAL',
          label: 'Cuti tahunan',
          remaining: 8,
          quota: 12,
        ),
        LeaveBalance(code: 'SPECIAL', label: 'Cuti khusus', remaining: 2),
      ],
    );
  });
}
