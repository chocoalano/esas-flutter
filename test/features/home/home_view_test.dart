import 'dart:async';

import 'package:esas/core/network/api_exception.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/features/home/presentation/widgets/home_metric.dart';
import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:esas/core/ui/components/app_card.dart';
import 'package:esas/core/ui/components/app_inline_notice.dart';
import 'package:esas/core/ui/controllers/bottom_nav_controller.dart';
import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/auth/presentation/routes/auth_routes.dart';
import 'package:esas/features/home/data/models/announcement.dart';
import 'package:esas/features/permit/data/models/leave_list.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/home_controller.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:esas/features/home/presentation/views/home_view.dart';
import 'package:esas/features/home/presentation/widgets/announcement_carousel.dart';
import 'package:esas/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:esas/features/home/presentation/widgets/home_skeleton.dart';
import 'package:esas/features/notification/presentation/routes/notification_routes.dart';
import 'package:esas/features/permit/presentation/routes/permit_routes.dart';
import 'package:esas/features/profile/presentation/routes/profile_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

/// Apa yang benar-benar dilihat dan bisa ditekan karyawan jam 06:50.
///
/// Pertanyaan yang dipatok berkas ini bukan "apakah tata letaknya bagus"
/// melainkan "apakah layar pertama aplikasi absensi punya cara untuk mengabsen,
/// dan apakah ajakannya berubah mengikuti keadaan hari ini". Versi sebelumnya
/// menjawab tidak untuk keduanya.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  late _MockHomeRepository repository;

  setUp(() {
    repository = _MockHomeRepository();

    when(() => repository.userName).thenReturn('Budi Santoso');
    when(() => repository.userAvatar).thenReturn('');
    when(() => repository.unreadNotifications).thenReturn(null);
    when(
      () => repository.recentPermits(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <Permit>[]);
    when(
      () => repository.activeAnnouncements(),
    ).thenAnswer((_) async => <Announcement>[]);
    when(
      () => repository.leaveBalances(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => <LeaveBalance>[]);
    when(
      () => repository.monthSummary(refresh: any(named: 'refresh')),
    ).thenAnswer((_) async => const MonthSummary(workedDays: 0, lateCount: 0));
  });

  tearDown(Get.reset);

  /// Halaman tiruan untuk setiap tujuan yang bisa ditekan dari Beranda, supaya
  /// `Get.offAllNamed` benar-benar berpindah alih-alih jatuh ke rute tak dikenal.
  GetPage stub(String name) => GetPage(
    name: name,
    page: () => Scaffold(body: Text('LAYAR $name')),
  );

  Future<void> pumpHome(
    WidgetTester tester, {
    DashboardTimes? times,
    Object? attendanceThrows,
    List<Announcement> announcements = const <Announcement>[],
    Completer<DashboardTimes>? pending,
    int? unread,
    List<LeaveBalance> leave = const <LeaveBalance>[],
    Object? leaveThrows,
    MonthSummary? summary,
    Object? summaryThrows,
  }) async {
    if (leaveThrows != null) {
      when(
        () => repository.leaveBalances(refresh: any(named: 'refresh')),
      ).thenThrow(leaveThrows);
    } else {
      when(
        () => repository.leaveBalances(refresh: any(named: 'refresh')),
      ).thenAnswer((_) async => leave);
    }

    if (summaryThrows != null) {
      when(
        () => repository.monthSummary(refresh: any(named: 'refresh')),
      ).thenThrow(summaryThrows);
    } else {
      when(
        () => repository.monthSummary(refresh: any(named: 'refresh')),
      ).thenAnswer(
        (_) async => summary ?? const MonthSummary(workedDays: 0, lateCount: 0),
      );
    }

    when(() => repository.unreadNotifications).thenReturn(unread);

    if (pending != null) {
      when(
        () => repository.todayAttendance(),
      ).thenAnswer((_) => pending.future);
    } else if (attendanceThrows != null) {
      when(() => repository.todayAttendance()).thenThrow(attendanceThrows);
    } else {
      when(
        () => repository.todayAttendance(),
      ).thenAnswer((_) async => times ?? const DashboardTimes());
    }

    when(
      () => repository.activeAnnouncements(),
    ).thenAnswer((_) async => announcements);

    Get.put<HomeController>(HomeController(repository: repository));
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
        getPages: <GetPage>[
          GetPage(name: HomeRoutes.home, page: () => const HomeView()),
          stub(AttendanceRoutes.attendance),
          stub(AttendanceRoutes.list),
          stub(PermitRoutes.permit),
          stub(PermitRoutes.list),
          stub(HomeRoutes.announcement),
          stub(NotificationRoutes.notification),
          stub(ProfileRoutes.profile),
          stub(AuthRoutes.login),
        ],
      ),
    );

    if (pending == null) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Sebuah label DI DALAM petak akses cepat.
  ///
  /// Dicari secara berjangkar karena bilah navigasi bawah memakai sebagian kata
  /// yang sama — "Pengajuan" ada di keduanya — dan sebuah finder yang cocok dua
  /// kali menguji tab, bukan petak.
  Finder quickAction(String label) => find.descendant(
    of: find.byType(HomeQuickActions),
    matching: find.text(label),
  );

  /// Ketuk sesuatu yang mungkin berada di bawah lipatan.
  ///
  /// Permukaan uji baku 800x600 lebih pendek daripada Beranda, dan petak akses
  /// cepat memang berada di bawahnya — sebuah kegagalan ketuk di sini berarti
  /// tesnya tidak menggulir, bukan berarti tombolnya tidak ada.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // `next_presence` included because the server always sends it in this state:
  // somebody rostered who has not clocked in is owed a clock-in, and the server
  // says so rather than leaving the screen to work it out from two times.
  const DashboardTimes workday = DashboardTimes(
    scheduleIn: '08:00',
    scheduleOut: '17:00',
    scheduleName: 'Shift Pagi',
    nextPresence: 'in',
  );

  group('ajakan absen', () {
    testWidgets('hari kerja yang belum diabsen menawarkan absen masuk', (
      tester,
    ) async {
      await pumpHome(tester, times: workday);

      expect(find.text('Belum absen'), findsOneWidget);
      expect(find.text('Absen masuk'), findsOneWidget);
      expect(find.text('Absen pulang'), findsNothing);
    });

    testWidgets('setelah absen masuk, ajakannya menjadi absen pulang', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          timeIn: '08:03',
          scheduleIn: '08:00',
          scheduleOut: '17:00',
          scheduleName: 'Shift Pagi',
          nextPresence: 'out',
        ),
      );

      expect(find.text('Sedang bekerja'), findsOneWidget);
      expect(find.text('Absen pulang'), findsWidgets);
      expect(find.text('Absen masuk'), findsNothing);
    });

    testWidgets('shift yang selesai tidak lagi menawarkan ketukan', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          timeIn: '08:03',
          timeOut: '17:04',
          scheduleIn: '08:00',
          scheduleOut: '17:00',
          scheduleName: 'Shift Pagi',
        ),
      );

      expect(find.text('Shift selesai'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
      expect(find.text('Lihat detail hari ini'), findsOneWidget);
    });

    testWidgets('akun yang tidak boleh mengabsen tidak diberi tombol', (
      tester,
    ) async {
      // Aturan UI README: tombol yang hanya bisa gagal lebih buruk daripada
      // tidak ada tombol.
      await pumpHome(
        tester,
        times: const DashboardTimes(
          scheduleIn: '08:00',
          scheduleOut: '17:00',
          scheduleName: 'Shift Pagi',
          attendanceEnabled: false,
          nextPresence: 'in',
        ),
      );

      expect(find.text('Absen masuk'), findsNothing);
      expect(find.text('Lihat riwayat absensi'), findsOneWidget);
    });

    testWidgets('hari tanpa jadwal tidak menyodorkan tombol absen', (
      tester,
    ) async {
      await pumpHome(tester, times: const DashboardTimes());

      expect(find.text('Tidak ada jadwal'), findsOneWidget);
      expect(find.text('Tidak ada jadwal kerja hari ini.'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
    });

    testWidgets('menekan ajakan membuka layar absensi', (tester) async {
      await pumpHome(tester, times: workday);

      await tester.tap(find.text('Absen masuk'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AttendanceRoutes.attendance);
    });
  });

  group('keadaan galat', () {
    testWidgets('galat absensi tampil ringkas, bukan sebagai kartu besar', (
      tester,
    ) async {
      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Koneksi terputus.'),
      );

      // Panelnya TETAP ada, dan kalimatnya ada di dalamnya. Sebelumnya slot ini
      // ditukar dengan sebuah pemberitahuan sebaris, dan Beranda kehilangan
      // jangkarnya persis ketika sesuatu sedang salah.
      expect(find.byType(TodayWorkCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TodayWorkCard),
          matching: find.text('Absensi belum dapat dimuat'),
        ),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsWidgets);
      // Jargon teknis tidak sampai ke layar; kalimatnya milik pengguna.
      expect(find.text('Gagal memuat'), findsNothing);
    });

    testWidgets(
      'sesi yang sudah mati ditawari masuk kembali, bukan coba lagi',
      (tester) async {
        // Tangkapan layar dasbor sungguhan: kalimatnya menyuruh orang masuk
        // kembali sementara tombolnya menawarkan "Coba lagi" — permintaan kedua
        // dengan token yang sama akan ditolak dengan cara yang persis sama,
        // selamanya.
        await pumpHome(
          tester,
          // 401, apa pun kalimatnya. Kalimat yang benar-benar dikirim backend
          // hari ini adalah rincian implementasi, dan layar tidak boleh
          // bergantung padanya — maupun menampilkannya.
          attendanceThrows: const ApiException(
            'Sesi ini dibuat sebelum fitur tersebut ada.',
            status: 401,
          ),
        );

        expect(find.text('Masuk kembali'), findsOneWidget);
        expect(find.text('Coba lagi'), findsNothing);
        expect(find.text('Sesi perlu diperbarui'), findsOneWidget);
        expect(find.text('Masuk kembali untuk melanjutkan.'), findsOneWidget);
        // Jargon backend tidak pernah sampai ke layar.
        expect(find.textContaining('sebelum fitur'), findsNothing);
      },
    );

    testWidgets('masuk kembali membuka layar masuk', (tester) async {
      await pumpHome(
        tester,
        attendanceThrows: const ApiException(
          'Sesi Anda berakhir.',
          status: 401,
        ),
      );

      await tapAndSettle(tester, find.text('Masuk kembali'));

      expect(Get.currentRoute, AuthRoutes.login);
    });

    testWidgets('galat absensi tidak menghapus akses cepat', (tester) async {
      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Koneksi terputus.'),
      );

      // Satu panel yang gagal tidak boleh membelanjakan layar milik panel lain.
      expect(find.text('Akses cepat'), findsOneWidget);
      expect(quickAction('Ajukan izin'), findsOneWidget);
      expect(quickAction('Riwayat'), findsOneWidget);
    });

    testWidgets('coba lagi memanggil ulang seluruh dasbor', (tester) async {
      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Koneksi terputus.'),
      );

      await tester.tap(find.text('Coba lagi').first);
      await tester.pumpAndSettle();

      verify(() => repository.todayAttendance()).called(greaterThan(1));
    });
  });

  group('tanpa bagian perlu perhatian', () {
    // Bagian itu dibubarkan karena ia mengulang panel di atasnya dengan bobot
    // yang membuat keduanya tampak setara. Yang diuji di sini bukan bahwa ia
    // hilang, melainkan bahwa tidak satu pun faktanya ikut hilang bersamanya.
    testWidgets('ketukan yang belum tercatat tidak dikatakan dua kali', (
      tester,
    ) async {
      await pumpHome(tester, times: workday);

      expect(find.text('Perlu perhatian'), findsNothing);
      expect(find.text('Absen masuk belum tercatat'), findsNothing);
      // Yang dikatakan panel protagonis, satu kali: keadaannya dan tombolnya.
      expect(find.text('Belum absen'), findsOneWidget);
      expect(find.text('Absen masuk'), findsOneWidget);
    });

    testWidgets('keterlambatan tetap disebutkan beserta durasinya', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          timeIn: '08:11',
          scheduleIn: '08:00',
          scheduleOut: '17:00',
          scheduleName: 'Shift Pagi',
          nextPresence: 'out',
        ),
      );

      expect(find.text('telat 11m'), findsOneWidget);
    });

    testWidgets('pengumuman yang gagal dimuat tidak dihitung sebagai nol', (
      tester,
    ) async {
      when(
        () => repository.activeAnnouncements(),
      ).thenThrow(const ApiException('Gagal.'));

      await pumpHome(tester, times: workday);

      expect(find.bySemanticsLabel(RegExp('pengumuman aktif')), findsNothing);
    });

    testWidgets('hitungan pengumuman pindah ke judul bagiannya', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: workday,
        announcements: <Announcement>[
          Announcement(id: 1, title: 'Kebijakan jam masuk'),
          Announcement(id: 2, title: 'Libur bersama'),
        ],
      );

      // Angkanya menjadi KALIMAT di bawah judul bagiannya. Sebagai "2"
      // tersendiri ia tidak mengatakan dua apa, dan mata membacanya sebagai
      // lencana keadaan padahal ia cuma hitungan.
      expect(find.text('2 informasi terbaru'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });
  });

  group('pengumuman', () {
    testWidgets('daftar kosong berbunyi positif, bukan seperti kegagalan', (
      tester,
    ) async {
      await pumpHome(tester, times: workday);

      expect(find.text('Belum ada pengumuman baru.'), findsOneWidget);
    });

    testWidgets('kartu menampilkan judul dan penerbitnya', (tester) async {
      await pumpHome(
        tester,
        times: workday,
        announcements: <Announcement>[
          Announcement(
            id: 1,
            title: 'Kebijakan jam masuk kerja',
            publishedBy: 'Departemen SDM',
            excerpt: 'Jam masuk dimajukan menjadi 07.30.',
          ),
        ],
      );

      expect(find.text('Kebijakan jam masuk kerja'), findsOneWidget);
      expect(find.textContaining('Departemen SDM'), findsOneWidget);
    });
  });

  group('navigasi', () {
    testWidgets('akses cepat membuka pengajuan izin', (tester) async {
      await pumpHome(tester, times: workday);

      await tapAndSettle(tester, quickAction('Ajukan izin'));

      expect(Get.currentRoute, PermitRoutes.permit);
    });

    testWidgets('akses cepat membuka riwayat absensi', (tester) async {
      await pumpHome(tester, times: workday);

      await tapAndSettle(tester, quickAction('Riwayat'));

      expect(Get.currentRoute, AttendanceRoutes.list);
    });

    testWidgets('akses cepat membuka daftar pengajuan', (tester) async {
      await pumpHome(tester, times: workday);

      await tapAndSettle(tester, quickAction('Pengajuan'));

      expect(Get.currentRoute, PermitRoutes.list);
    });

    testWidgets('lonceng membuka notifikasi', (tester) async {
      await pumpHome(tester, times: workday);

      await tester.tap(find.bySemanticsLabel('Notifikasi'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, NotificationRoutes.notification);
    });

    testWidgets('semua pengumuman membuka daftarnya', (tester) async {
      await pumpHome(tester, times: workday);

      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, HomeRoutes.announcement);
    });
  });

  group('memuat', () {
    testWidgets('pembukaan dingin menggambar rangka, bukan data palsu', (
      tester,
    ) async {
      final pending = Completer<DashboardTimes>();

      await pumpHome(tester, pending: pending);

      expect(find.byType(HomeHeroSkeleton), findsOneWidget);
      // Tidak ada pernyataan percaya diri tentang data yang belum sampai.
      expect(find.text('Belum absen'), findsNothing);
      expect(find.text('Absen masuk'), findsNothing);

      pending.complete(workday);
      await tester.pumpAndSettle();

      expect(find.byType(HomeHeroSkeleton), findsNothing);
      expect(find.text('Absen masuk'), findsOneWidget);
    });

    testWidgets('sapaan tetap ada selama data belum sampai', (tester) async {
      final pending = Completer<DashboardTimes>();

      await pumpHome(tester, pending: pending);

      // Nama diri: kapital per KATA, bukan per kalimat.
      expect(find.text('Budi Santoso'), findsOneWidget);

      pending.complete(workday);
      await tester.pumpAndSettle();
    });
  });

  group('jenis hari', () {
    testWidgets('hari libur nasional disebut namanya', (tester) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          dayContext: DayContext(
            type: HomeDayType.holiday,
            holidayName: 'Hari Kemerdekaan Republik Indonesia',
          ),
        ),
      );

      expect(find.text('Libur nasional'), findsOneWidget);
      expect(find.text('Hari Kemerdekaan Republik Indonesia'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
    });

    testWidgets('giliran libur tidak disebut libur nasional', (tester) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          dayContext: DayContext(type: HomeDayType.dayOff),
        ),
      );

      expect(find.text('Hari libur'), findsWidgets);
      expect(find.text('Tidak ada jadwal kerja hari ini.'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
      // Beranda sudah menyebut nama orangnya di kepala halaman; kalimat DI
      // DALAM panel protagonis tidak perlu menunjuknya lagi.
      expect(
        find.descendant(
          of: find.byType(TodayWorkCard),
          matching: find.textContaining('Anda'),
        ),
        findsNothing,
      );
    });

    testWidgets('cuti yang disetujui tidak diperlakukan sebagai kelalaian', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          dayContext: DayContext(type: HomeDayType.leave),
        ),
      );

      expect(find.text('Cuti disetujui'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
    });

    testWidgets('backend lama tetap menggambar halaman yang benar', (
      tester,
    ) async {
      // Tanpa `day_context`: kalimatnya tidak mengklaim hari ini libur.
      await pumpHome(tester, times: const DashboardTimes());

      expect(find.text('Tidak ada jadwal'), findsOneWidget);
      expect(find.text('Tidak ada jadwal kerja hari ini.'), findsOneWidget);
      expect(find.text('Absen masuk'), findsNothing);
    });

    testWidgets('hari libur yang tetap dirosterkan tetap bisa mengabsen', (
      tester,
    ) async {
      // Aturan bisnisnya milik server: ada jadwal dan ada ketukan berikutnya,
      // jadi tombolnya ada — apa pun kata kalender.
      await pumpHome(
        tester,
        times: const DashboardTimes(
          scheduleIn: '08:00',
          scheduleOut: '17:00',
          scheduleName: 'Shift Pagi',
          nextPresence: 'in',
          dayContext: DayContext(type: HomeDayType.holiday),
        ),
      );

      expect(find.text('Absen masuk'), findsOneWidget);
    });
  });

  group('lencana notifikasi', () {
    testWidgets('tanpa hitungan, lonceng adalah pintu tanpa angka', (
      tester,
    ) async {
      await pumpHome(tester, times: workday);

      expect(find.bySemanticsLabel('Notifikasi'), findsOneWidget);
    });

    testWidgets('nol tidak menggambar lencana', (tester) async {
      await pumpHome(tester, times: workday, unread: 0);

      expect(find.bySemanticsLabel('Notifikasi'), findsOneWidget);
    });

    testWidgets('hitungan digambar dan ikut dibacakan pembaca layar', (
      tester,
    ) async {
      await pumpHome(tester, times: workday, unread: 3);

      expect(find.text('3'), findsWidgets);
      expect(
        find.bySemanticsLabel('Notifikasi, 3 belum dibaca'),
        findsOneWidget,
      );
    });

    testWidgets('hitungan besar dipendekkan alih-alih merusak tata letak', (
      tester,
    ) async {
      await pumpHome(tester, times: workday, unread: 250);

      expect(find.text('99+'), findsOneWidget);
    });
  });

  group('shift lintas tengah malam', () {
    testWidgets('shift malam yang berjalan tidak menampilkan durasi negatif', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          timeIn: '22:03',
          scheduleIn: '22:00',
          scheduleOut: '06:00',
          scheduleName: 'Shift Malam',
          nextPresence: 'out',
        ),
      );

      expect(find.text('Sedang bekerja'), findsOneWidget);
      expect(find.text('Absen pulang'), findsWidgets);
      // Tidak ada angka berawalan minus di mana pun pada kartu protagonis.
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('shift malam yang selesai menampilkan totalnya', (
      tester,
    ) async {
      await pumpHome(
        tester,
        times: const DashboardTimes(
          timeIn: '22:00',
          timeOut: '06:00',
          scheduleIn: '22:00',
          scheduleOut: '06:00',
          scheduleName: 'Shift Malam',
        ),
      );

      expect(find.text('Shift selesai'), findsOneWidget);
      expect(find.text('8j'), findsOneWidget);
    });
  });

  group('responsif', () {
    // Tujuh lebar yang benar-benar dikirim perangkat di lapangan, dikali tiga
    // skala teks. Probe bersama di `layout_overflow_test` menguji 320/360/375/
    // 412 untuk SETIAP layar; yang ditambahkan di sini adalah tiga lebar sisa
    // yang khusus diminta untuk Beranda — 390 dan 393 (iPhone modern) dan 430
    // (ponsel besar) — supaya tidak ada yang disimpulkan dari interpolasi.
    const List<double> widths = <double>[320, 360, 375, 390, 393, 412, 430];
    const List<double> scales = <double>[1.0, 1.3, 1.5];

    for (final double width in widths) {
      for (final double scale in scales) {
        testWidgets('${width.toInt()}dp pada skala teks $scale tidak meluap', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
          final void Function(FlutterErrorDetails)? previous =
              FlutterError.onError;
          FlutterError.onError = caught.add;

          await pumpHome(
            tester,
            times: const DashboardTimes(
              timeIn: '08:11',
              scheduleIn: '08:00',
              scheduleOut: '17:00',
              // Nama shift dan pengumuman sengaja panjang: label pendek tidak
              // pernah meluap, jadi ia tidak membuktikan apa pun.
              scheduleName: 'Shift Pagi Produksi Non-Stop',
              nextPresence: 'out',
            ),
            announcements: <Announcement>[
              Announcement(
                id: 1,
                title:
                    'Kebijakan jam masuk kerja, izin terlambat dan pulang awal',
                publishedBy: 'Departemen Sumber Daya Manusia',
                excerpt:
                    'Jam masuk dimajukan menjadi 07.30 dan jam pulang menjadi '
                    '16.00 untuk seluruh karyawan bagian produksi.',
              ),
            ],
            unread: 128,
          );

          tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(
            tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
          );
          await tester.pumpAndSettle();

          FlutterError.onError = previous;
          tester.takeException();

          expect(
            caught.map((FlutterErrorDetails d) => d.toString()).join('\n\n'),
            isEmpty,
          );

          // Ajakan utama harus tetap BISA DICAPAI, bukan sekadar tidak meluap:
          // sebuah tombol yang terdorong keluar layar sama tidak bergunanya
          // dengan tombol yang tidak ada.
          expect(find.text('Absen pulang'), findsWidgets);
        });
      }
    }
  });

  group('keadaan tangkapan layar: absensi tidak tersedia', () {
    /// Persis keadaan yang dilaporkan dari simulator: karyawan ada, absensi
    /// dijawab 403, empat akses cepat, tiga pengumuman.
    Future<void> pumpForbidden(WidgetTester tester) => pumpHome(
      tester,
      attendanceThrows: const ApiException(
        'Sesi ini dibuat sebelum fitur tersebut ada.',
        status: 403,
      ),
      announcements: <Announcement>[
        Announcement(
          id: 1,
          title: 'ALUR PERMINTAAN SLIP GAJI',
          publishedBy: 'Tubagus Angga',
          excerpt: '&nbsp;BERIKUT LINK UNTUK MENGAKSES FILE TERSEBUT',
        ),
        Announcement(id: 2, title: 'Libur bersama', publishedBy: 'HRD'),
        Announcement(id: 3, title: 'Perubahan jam kerja', publishedBy: 'HRD'),
      ],
    );

    testWidgets('panel protagonis TETAP ada', (tester) async {
      // Regresi yang ditemukan di simulator: seluruh panel ditukar dengan satu
      // kalimat, sehingga sesudah kepala halaman langsung akses cepat dan
      // Beranda kehilangan jangkarnya justru ketika sesuatu sedang salah.
      await pumpForbidden(tester);

      expect(find.byType(TodayWorkCard), findsOneWidget);
      expect(find.text('HARI INI'), findsOneWidget);
    });

    testWidgets('kalimatnya berada DI DALAM panel protagonis', (tester) async {
      await pumpForbidden(tester);

      expect(
        find.descendant(
          of: find.byType(TodayWorkCard),
          matching: find.text('Absensi belum dapat dimuat'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('403 TIDAK BOLEH mengklaim absensi dimatikan untuk akun ini', (
      tester,
    ) async {
      // Dilaporkan dari lapangan: akun yang absensinya jelas-jelas aktif tetap
      // dikabari bahwa fiturnya belum aktif. Sebabnya bukan data melainkan
      // KESIMPULAN — layar mengarang sebuah fakta produk dari sebuah status
      // transport. Satu-satunya pernyataan sah tentang kapabilitas karyawan
      // adalah `attendance_enabled: false` di dalam respons yang berhasil.
      await pumpForbidden(tester);

      expect(find.textContaining('belum aktif'), findsNothing);
      expect(find.textContaining('tidak aktif'), findsNothing);
      expect(find.textContaining('akun ini'), findsNothing);
      expect(find.textContaining('akun Anda'), findsNothing);
    });

    testWidgets('403 tetap menawarkan jalan keluar yang tidak merusak', (
      tester,
    ) async {
      await pumpForbidden(tester);

      expect(find.byType(AppInlineNotice), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
      // Tidak mengeluarkan orang dari sesinya untuk menebak sebuah penolakan.
      expect(find.text('Masuk kembali'), findsNothing);
    });

    testWidgets('hanya attendance_enabled: false yang boleh mengklaimnya', (
      tester,
    ) async {
      // Jalur yang SAH: respons berhasil, dan servernya sendiri yang berkata
      // akun ini tidak boleh mengabsen.
      await pumpHome(
        tester,
        times: const DashboardTimes(attendanceEnabled: false),
      );

      expect(
        find.text('Fitur absensi belum aktif untuk akun ini.'),
        findsOneWidget,
      );
    });

    testWidgets('konteks hari ini tetap terjawab', (tester) async {
      await pumpForbidden(tester);

      expect(
        find.descendant(
          of: find.byType(TodayWorkCard),
          matching: find.textContaining('September'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('akses cepat dan pengumuman tetap utuh', (tester) async {
      await pumpForbidden(tester);

      expect(quickAction('Absen'), findsOneWidget);
      expect(quickAction('Ajukan izin'), findsOneWidget);
      expect(quickAction('Pengajuan'), findsOneWidget);
      expect(quickAction('Riwayat'), findsOneWidget);
      expect(find.text('3 informasi terbaru'), findsOneWidget);
    });

    testWidgets('entitas HTML tidak pernah sampai ke layar', (tester) async {
      await pumpForbidden(tester);

      expect(find.textContaining('&nbsp;'), findsNothing);
      expect(find.textContaining('&amp;'), findsNothing);
      // Cuplikannya ikut diturunkan hurufnya, seperti judulnya — entitasnya
      // hilang DAN teriakannya reda.
      expect(
        find.textContaining('Berikut link untuk mengakses file tersebut'),
        findsOneWidget,
      );
    });

    testWidgets('hitungan pengumuman bukan angka yatim', (tester) async {
      await pumpForbidden(tester);

      // Sebagai "3" tersendiri ia tidak mengatakan tiga apa.
      expect(find.text('3'), findsNothing);
    });
  });

  group('komposisi halaman', () {
    testWidgets('urutannya hari ini → aksi → kabar, juga saat absensi mati', (
      tester,
    ) async {
      // Yang rusak di simulator bukan sebuah widget melainkan URUTANNYA: begitu
      // panel protagonis dihapus, akses cepat naik menjadi isi utama layar.
      // Tes ini memaku hierarkinya, bukan pikselnya.
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Tidak diizinkan.', status: 403),
        announcements: <Announcement>[
          Announcement(id: 1, title: 'Kebijakan baru', publishedBy: 'HRD'),
        ],
      );

      final double hero = tester.getTopLeft(find.byType(TodayWorkCard)).dy;
      final double actions = tester
          .getTopLeft(find.byType(HomeQuickActions))
          .dy;
      final double news = tester
          .getTopLeft(find.byType(AnnouncementCarousel))
          .dy;

      expect(hero, lessThan(actions));
      expect(actions, lessThan(news));
    });

    testWidgets('tidak ada pita bergaris selebar layar lagi', (tester) async {
      // Bedanya dengan kanvas cuma 1,02:1, jadi yang benar-benar terlihat dari
      // pita itu hanyalah dua garis rambut — dan dua garis itu membuat halaman
      // terbaca seperti halaman pengaturan yang dikelompokkan.
      await pumpHome(tester, times: workday);

      // Dibatasi ke ISI yang menggulir. Bilah navigasi bawah juga punya garis
      // rambut di tepi atasnya, dan garis itu memang miliknya: ia memisahkan
      // krom aplikasi dari halaman, bukan satu bagian halaman dari bagian lain.
      final Iterable<Container> banded = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Container),
            ),
          )
          .where((Container c) {
            final Decoration? d = c.decoration;
            return d is BoxDecoration &&
                d.border is Border &&
                (d.border! as Border).top.width > 0 &&
                (d.border! as Border).left == BorderSide.none;
          });

      expect(banded, isEmpty);
    });
  });

  group('perataan carousel', () {
    testWidgets(
      'kartu pertama rata dengan margin halaman saat Beranda dibuka',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpHome(
          tester,
          times: workday,
          announcements: <Announcement>[
            Announcement(id: 1, title: 'Pertama', publishedBy: 'HRD'),
            Announcement(id: 2, title: 'Kedua', publishedBy: 'HRD'),
            Announcement(id: 3, title: 'Ketiga', publishedBy: 'HRD'),
          ],
        );

        final Finder firstCard = find
            .descendant(
              of: find.byType(AnnouncementCarousel),
              matching: find.byType(AppCard),
            )
            .first;

        await tester.ensureVisible(firstCard);
        await tester.pumpAndSettle();

        // Tepi kiri kartu pertama HARUS sama dengan margin halaman: tidak ada
        // potongan kartu sebelumnya yang mengintip di kiri saat halaman dibuka.
        expect(tester.getTopLeft(firstCard).dx, closeTo(AppSpacing.page, 0.5));

        // Dan kartu pertama itu memang pengumuman pertama, bukan yang tengah.
        expect(
          find.descendant(of: firstCard, matching: find.text('Pertama')),
          findsOneWidget,
        );
      },
    );
  });

  group('zona konteks pribadi', () {
    testWidgets('berisi kedua bagian, di BAWAH pengumuman', (tester) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(
        tester,
        times: workday,
        announcements: <Announcement>[
          Announcement(id: 1, title: 'Kebijakan baru', publishedBy: 'HRD'),
        ],
        summary: const MonthSummary(workedDays: 12, lateCount: 1),
        leave: const <LeaveBalance>[
          LeaveBalance(
            code: 'ANNUAL',
            label: 'Cuti tahunan',
            remaining: 8,
            quota: 12,
          ),
        ],
      );

      final double news = tester
          .getTopLeft(find.byType(AnnouncementCarousel))
          .dy;
      final double month = tester
          .getTopLeft(find.text('Ringkasan bulan ini'))
          .dy;
      final double leaveY = tester.getTopLeft(find.text('Sisa cuti')).dy;

      // Urutannya: hari ini → aksi → kabar perusahaan → konteks pribadi.
      expect(news, lessThan(month));
      expect(month, lessThan(leaveY));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('kosong tetapi berhasil dimuat: judul tetap, satu baris', (
      tester,
    ) async {
      // Inilah keadaan tangkapan layar: kedua bagian berhasil dimuat dan
      // jawabannya kosong. Sebelumnya keduanya menghilang bersama judulnya, dan
      // separuh bawah Beranda berhenti mendadak setelah korsel.
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(tester, times: workday);

      expect(find.text('Ringkasan bulan ini'), findsOneWidget);
      expect(find.text('Sisa cuti'), findsOneWidget);
      expect(find.text('Belum ada aktivitas kehadiran'), findsOneWidget);
      expect(find.text('Belum ada saldo cuti'), findsOneWidget);
      // Kosong tidak membawa chevron: tidak ada saldo yang bisa dibuka. Yang
      // ditawarkan justru sesuatu yang berguna — daftar pengajuan.
      expect(find.text('Ajukan'), findsNothing);
      expect(find.text('Lihat pengajuan'), findsOneWidget);
      // Kosong bukan nol: tidak ada ubin metrik yang dikarang.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('gagal dimuat: hilang diam-diam, tanpa peringatan', (
      tester,
    ) async {
      // Bagian sekunder yang gagal tidak berteriak. Sebuah dasbor dengan
      // peringatan di setiap bagian mengajari orang mengabaikan semuanya;
      // kegagalannya sudah tercatat di log oleh `HomeController._load`.
      await pumpHome(
        tester,
        times: workday,
        leaveThrows: const ApiException('Gagal.', status: 500),
        summaryThrows: const ApiException('Gagal.', status: 500),
      );

      expect(find.text('Ringkasan bulan ini'), findsNothing);
      expect(find.text('Sisa cuti'), findsNothing);
      expect(find.text('Sisa cuti belum dapat dimuat.'), findsNothing);
    });

    testWidgets('kegagalan sebagian: yang berhasil tetap digambar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(
        tester,
        times: workday,
        summaryThrows: const ApiException('Gagal.', status: 500),
        leave: const <LeaveBalance>[
          LeaveBalance(code: 'ANNUAL', label: 'Cuti tahunan', remaining: 8),
        ],
      );

      expect(find.text('Ringkasan bulan ini'), findsNothing);
      expect(find.text('Sisa cuti'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('absensi 403 tidak menghilangkan konteks pribadi', (
      tester,
    ) async {
      // Panel yang tidak berkerabat tidak boleh ikut jatuh bersama absensi.
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Ditolak.', status: 403),
        announcements: <Announcement>[
          Announcement(id: 1, title: 'Kebijakan baru', publishedBy: 'HRD'),
        ],
        summary: const MonthSummary(workedDays: 12, lateCount: 1),
        leave: const <LeaveBalance>[
          LeaveBalance(code: 'ANNUAL', label: 'Cuti tahunan', remaining: 8),
        ],
      );

      expect(find.byType(TodayWorkCard), findsOneWidget);
      expect(find.text('Ringkasan bulan ini'), findsOneWidget);
      expect(find.text('Sisa cuti'), findsOneWidget);
      expect(find.byType(AnnouncementCarousel), findsOneWidget);
    });
  });

  group('ringkasan bulan ini', () {
    Future<void> pumpTall(WidgetTester tester, {MonthSummary? summary}) {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      return pumpHome(tester, times: workday, summary: summary);
    }

    testWidgets('angka dulu, label sesudahnya', (tester) async {
      await pumpTall(
        tester,
        summary: const MonthSummary(workedDays: 12, lateCount: 1),
      );

      final double value = tester.getTopLeft(find.text('12')).dy;
      final double label = tester.getTopLeft(find.text('Hari kerja')).dy;

      // Sebuah dasbor yang menuntut orang MEMBACA untuk tahu angkanya bukan
      // dasbor melainkan laporan.
      expect(value, lessThan(label));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Terlambat'), findsOneWidget);
    });

    testWidgets('bar dua nada memakai penyebut yang benar-benar ada', (
      tester,
    ) async {
      await pumpTall(
        tester,
        summary: const MonthSummary(workedDays: 12, lateCount: 1),
      );

      // 11 tepat waktu + 1 terlambat = 12 hari kerja, tepat. Tidak ada
      // persentase kehadiran: penyebutnya adalah hari kerja yang DIHARAPKAN,
      // dan tidak ada endpoint yang mengirimkannya.
      expect(find.byType(HomeSplitBar), findsWidgets);
      expect(find.text('11 tepat waktu'), findsOneWidget);
      expect(find.text('1 terlambat'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('nol keterlambatan tidak diwarnai peringatan', (tester) async {
      await pumpTall(
        tester,
        summary: const MonthSummary(workedDays: 8, lateCount: 0),
      );

      expect(find.text('8 tepat waktu'), findsOneWidget);
      expect(find.text('0 terlambat'), findsNothing);
    });

    testWidgets('bulan kosong: satu baris, bukan tiga angka nol', (
      tester,
    ) async {
      await pumpTall(
        tester,
        summary: const MonthSummary(workedDays: 0, lateCount: 0),
      );

      expect(find.text('Belum ada aktivitas kehadiran'), findsOneWidget);
      expect(find.byType(HomeSplitBar), findsNothing);
    });
  });

  group('sisa cuti adaptif', () {
    Future<void> pumpLeave(WidgetTester tester, List<LeaveBalance> leave) {
      tester.view.physicalSize = const Size(390, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      return pumpHome(tester, times: workday, leave: leave);
    }

    testWidgets('satu jenis: saldo tunggal, dengan bar bila jatah diketahui', (
      tester,
    ) async {
      await pumpLeave(tester, const <LeaveBalance>[
        LeaveBalance(
          code: 'ANNUAL',
          label: 'Cuti tahunan',
          remaining: 8,
          quota: 12,
        ),
      ]);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('Cuti tahunan'), findsOneWidget);
      // `terpakai = quota - remaining` adalah aritmetika atas dua angka
      // kanonis, bukan tebakan.
      expect(find.text('4 dari 12 hari terpakai'), findsOneWidget);
    });

    testWidgets('tanpa jatah: angka saja, tanpa lintasan yang dikarang', (
      tester,
    ) async {
      await pumpLeave(tester, const <LeaveBalance>[
        LeaveBalance(code: 'ANNUAL', label: 'Cuti tahunan', remaining: 8),
      ]);

      expect(find.text('8'), findsOneWidget);
      expect(find.byType(HomeSplitBar), findsNothing);
      expect(find.textContaining('terpakai'), findsNothing);
    });

    testWidgets('dua jenis: dua kolom', (tester) async {
      await pumpLeave(tester, const <LeaveBalance>[
        LeaveBalance(code: 'ANNUAL', label: 'Cuti tahunan', remaining: 8),
        LeaveBalance(code: 'SPECIAL', label: 'Cuti khusus', remaining: 2),
      ]);

      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Lihat 1 jenis izin lainnya'), findsNothing);
    });

    testWidgets('empat jenis: dua ditampilkan, sisanya di balik satu tautan', (
      tester,
    ) async {
      await pumpLeave(tester, const <LeaveBalance>[
        LeaveBalance(code: 'ANNUAL', label: 'Cuti tahunan', remaining: 8),
        LeaveBalance(code: 'SPECIAL', label: 'Cuti khusus', remaining: 2),
        LeaveBalance(code: 'SICK', label: 'Sakit', remaining: 5),
        LeaveBalance(code: 'MARRIAGE', label: 'Cuti menikah', remaining: 3),
      ]);

      // Tidak pernah tiga kolom atau lebih: pada layar sempit angka besar di
      // dalamnya berhenti terbaca sebagai angka besar.
      expect(find.text('Cuti tahunan'), findsOneWidget);
      expect(find.text('Cuti khusus'), findsOneWidget);
      expect(find.text('Sakit'), findsNothing);
      expect(find.text('Lihat 2 jenis izin lainnya'), findsOneWidget);
    });

    testWidgets('kosong: satu baris tenang, dan tanpa chevron', (tester) async {
      await pumpLeave(tester, const <LeaveBalance>[]);

      expect(find.text('Belum ada saldo cuti'), findsOneWidget);
      expect(find.text('Ajukan'), findsNothing);
    });
  });

  group('sorotan akses cepat', () {
    testWidgets('petak absen bersorot ketika ketukan memang diharapkan', (
      tester,
    ) async {
      await pumpHome(tester, times: workday);

      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HomeQuickActions),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;

      expect(decoration.color, AppPalette.light.brandSubtle);
    });

    testWidgets('sorotan mati ketika absensi tidak tersedia', (tester) async {
      // Petak bersorot yang menuju pintu terkunci adalah janji yang tidak bisa
      // ditepati.
      await pumpHome(
        tester,
        attendanceThrows: const ApiException('Ditolak.', status: 403),
      );

      final Container box = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HomeQuickActions),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = box.decoration! as BoxDecoration;

      expect(decoration.color, isNot(AppPalette.light.brandSubtle));
    });
  });

  group('responsif: widget berisi data', () {
    // Probe responsif yang sudah ada memakai Beranda dengan ringkasan dan saldo
    // KOSONG — yaitu keadaan yang paling sedikit berisiko meluap. Risikonya ada
    // di keadaan berisi: angka besar plus satuan plus label, dua kolom, pada
    // layar sempit dengan skala teks besar.
    for (final double width in <double>[320, 360, 430]) {
      for (final double scale in <double>[1.0, 1.5]) {
        testWidgets('${width.toInt()}dp x$scale tidak meluap', (tester) async {
          tester.view.physicalSize = Size(width, 2200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
          final void Function(FlutterErrorDetails)? previous =
              FlutterError.onError;
          FlutterError.onError = caught.add;

          await pumpHome(
            tester,
            times: workday,
            summary: const MonthSummary(workedDays: 22, lateCount: 13),
            leave: const <LeaveBalance>[
              LeaveBalance(
                code: 'ANNUAL',
                label: 'Cuti tahunan karyawan tetap',
                remaining: 12,
                quota: 24,
              ),
              LeaveBalance(
                code: 'SPECIAL',
                label: 'Cuti khusus keperluan keluarga',
                remaining: 3,
                quota: 6,
              ),
            ],
          );

          tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(
            tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
          );
          await tester.pumpAndSettle();

          FlutterError.onError = previous;
          tester.takeException();

          expect(
            caught.map((FlutterErrorDetails d) => d.toString()).join('\n\n'),
            isEmpty,
          );

          // Angkanya harus tetap ADA, bukan sekadar tidak meluap: sebuah metrik
          // yang menyusut sampai hilang tidak lebih baik daripada yang meluap.
          expect(find.text('22'), findsOneWidget);
          expect(find.text('12'), findsOneWidget);
        });
      }
    }
  });
}
