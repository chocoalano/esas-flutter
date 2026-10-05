import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/routes/home_pages.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/widgets/home_recent_activity.dart';
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

/// Beranda seperti yang benar-benar dibangun APLIKASI, bukan seperti yang
/// dibangun sebuah tes.
///
/// Berkas ini ada karena sebuah laporan implementasi pernah menyatakan bahwa
/// penanda bagian sudah memakai huruf biasa, sementara tangkapan layar
/// simulator masih memperlihatkan `AKSES CEPAT`. Ternyata sebabnya bukan kode —
/// binari di simulator delapan jam lebih tua daripada sumbernya — tetapi
/// kejadian itu memperlihatkan lubang nyata dalam suite: setiap tes Beranda
/// membangun `HomeView` LANGSUNG, sehingga tidak satu pun dari mereka
/// membuktikan bahwa tabel rute, binding, dan controller sungguhan menghasilkan
/// layar yang sama.
///
/// Yang dilalui di sini: `HomeRoutes.home` → `HomePages.pages` → `HomeBinding`
/// → `HomeController` → `HomeView` → widget anak. `HomeBinding` memeriksa
/// `Get.isRegistered<HomeRepository>()` lebih dulu, dan itulah sambungan yang
/// dipakai tes ini untuk menitipkan repository tiruan tanpa menyentuh jaringan.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockHomeRepository repository;

  setUp(() {
    repository = _MockHomeRepository();

    when(() => repository.userName).thenReturn('Alan Gentina');
    when(() => repository.userAvatar).thenReturn('');
    when(() => repository.unreadNotifications).thenReturn(null);
    // Keadaan runtime yang dilaporkan dari simulator, apa adanya.
    when(
      () => repository.todayAttendance(),
    ).thenThrow(const ApiException('Ditolak.', status: 403));
    when(() => repository.activeAnnouncements()).thenAnswer(
      (_) async => <Announcement>[
        Announcement(id: 1, title: 'Alur permintaan slip gaji'),
        Announcement(id: 2, title: 'Libur bersama'),
        Announcement(id: 3, title: 'Perubahan jam kerja'),
      ],
    );
    when(
      () => repository.leaveBalances(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => <LeaveBalance>[]);
    when(
      () => repository.monthSummary(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => const MonthSummary(workedDays: 0, lateCount: 0));
    when(
      () => repository.recentPermits(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <Permit>[]);
  });

  tearDown(Get.reset);

  Future<void> pumpProductionHome(WidgetTester tester) async {
    // Dititipkan SEBELUM rute dibuka, supaya `HomeBinding` menemukannya alih-
    // alih membangun repository sungguhan di atas `ApiClient`.
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
      GetMaterialApp(
        locale: const Locale('id', 'ID'),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale('id', 'ID')],
        theme: AppTheme.lightTheme,
        initialRoute: HomeRoutes.home,
        // Tabel rute PRODUKSI, bukan halaman tiruan.
        getPages: HomePages.pages,
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('penanda bagian memakai huruf biasa, bukan kapital', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpProductionHome(tester);

    for (final String title in const <String>[
      'Akses cepat',
      'Pengumuman',
      'Aktivitas terbaru',
      'Ringkasan bulan ini',
      'Sisa cuti',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(
        find.text(title.toUpperCase()),
        findsNothing,
        reason: '${title.toUpperCase()} tidak boleh muncul',
      );
    }
  });

  testWidgets('kelima bagian tergambar walau absensi ditolak 403', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpProductionHome(tester);

    expect(find.byType(HomeRecentActivity), findsOneWidget);
    expect(find.text('Belum ada pengajuan'), findsOneWidget);
    expect(find.text('Belum ada aktivitas kehadiran'), findsOneWidget);
    expect(find.text('Belum ada saldo cuti'), findsOneWidget);
  });

  testWidgets('binding produksi memanggil kelima panel, tepat sekali', (
    tester,
  ) async {
    await pumpProductionHome(tester);

    verify(() => repository.todayAttendance()).called(1);
    verify(() => repository.activeAnnouncements()).called(1);
    verify(
      () => repository.recentPermits(limit: any(named: 'limit')),
    ).called(1);
    verify(
      () => repository.monthSummary(refresh: any(named: 'refresh')),
    ).called(1);
    verify(
      () => repository.leaveBalances(refresh: any(named: 'refresh')),
    ).called(1);
  });
}
