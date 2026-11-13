import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/home/data/models/schedule_calendar.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/schedule_calendar_controller.dart';
import 'package:esas/features/home/presentation/views/schedule_calendar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRepository extends Mock implements HomeRepository {}

void main() {
  late _MockHomeRepository repository;

  final sampleCalendar = ScheduleCalendar(
    from: '2026-11-01',
    to: '2026-11-30',
    holidays: const [
      ScheduleHoliday(
        date: '2026-11-10',
        name: 'Hari Pahlawan',
        type: 'holiday',
      ),
    ],
    schedule: const [
      ScheduleCalendarItem(
        date: '2026-11-10',
        shift: 'Libur Nasional',
        dayType: 'holiday',
      ),
      ScheduleCalendarItem(
        date: '2026-11-12',
        shift: 'Shift Regular Pagi',
        startsAt: '08:00',
        endsAt: '17:00',
        dayType: 'workday',
      ),
      ScheduleCalendarItem(
        date: '2026-11-15',
        shift: 'Off',
        dayType: 'day_off',
      ),
      ScheduleCalendarItem(
        date: '2026-11-18',
        shift: 'Cuti Tahunan',
        dayType: 'leave',
      ),
    ],
  );

  setUp(() {
    Get.testMode = true;
    repository = _MockHomeRepository();

    when(
      () => repository.scheduleCalendar(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => sampleCalendar);
  });

  tearDown(Get.reset);

  group('ScheduleCalendarController Tests', () {
    test('initializes with pinned workspace clock date', () async {
      final controller = ScheduleCalendarController(
        repository: repository,
        today: () => DateTime.utc(2026, 11, 12),
      );

      expect(controller.currentMonth.value, DateTime.utc(2026, 11, 1));
      expect(controller.selectedDate.value, DateTime.utc(2026, 11, 12));

      await controller.loadSchedule();

      expect(controller.scheduleMap.length, 4);
      expect(controller.holidayMap.length, 1);

      expect(controller.selectedSchedule?.shift, 'Shift Regular Pagi');
      expect(controller.selectedSchedule?.startsAt, '08:00');
      expect(controller.selectedSchedule?.endsAt, '17:00');
      expect(controller.selectedSchedule?.isWorkday, isTrue);

      // Check holiday lookup
      final nov10 = DateTime.utc(2026, 11, 10);
      expect(controller.holidayFor(nov10)?.name, 'Hari Pahlawan');
      expect(controller.scheduleFor(nov10)?.isHoliday, isTrue);

      // Check day off lookup
      final nov15 = DateTime.utc(2026, 11, 15);
      expect(controller.scheduleFor(nov15)?.isDayOff, isTrue);

      // Check leave lookup
      final nov18 = DateTime.utc(2026, 11, 18);
      expect(controller.scheduleFor(nov18)?.isLeave, isTrue);
    });

    test('navigates next and previous month correctly', () async {
      final controller = ScheduleCalendarController(
        repository: repository,
        today: () => DateTime.utc(2026, 11, 12),
      );

      controller.nextMonth();
      expect(controller.currentMonth.value, DateTime.utc(2026, 12, 1));

      controller.previousMonth();
      expect(controller.currentMonth.value, DateTime.utc(2026, 11, 1));

      controller.selectDate(DateTime.utc(2026, 11, 25));
      expect(controller.selectedDate.value, DateTime.utc(2026, 11, 25));

      controller.goToToday();
      expect(controller.selectedDate.value, DateTime.utc(2026, 11, 12));
    });
  });

  group('ScheduleCalendarView Widget Tests', () {
    testWidgets('renders monthly calendar model, grid, legend, and day details', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = ScheduleCalendarController(
        repository: repository,
        today: () => DateTime.utc(2026, 11, 12),
      );

      Get.put<ScheduleCalendarController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: const ScheduleCalendarView(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AppBar title
      expect(find.text('Kalender & Jadwal Shift'), findsOneWidget);

      // Verify Month Navigator shows "November 2026"
      expect(find.text('November 2026'), findsOneWidget);

      // Verify Weekday Headers are rendered
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Sel'), findsOneWidget);
      expect(find.text('Rab'), findsOneWidget);
      expect(find.text('Kam'), findsOneWidget);
      expect(find.text('Jum'), findsOneWidget);
      expect(find.text('Sab'), findsOneWidget);
      expect(find.text('Min'), findsOneWidget);

      // Verify Legend items are rendered
      expect(find.text('Kerja'), findsWidgets);
      expect(find.text('Libur'), findsWidgets);
      expect(find.text('Libur Nasional'), findsWidgets);
      expect(find.text('Cuti'), findsWidgets);

      // Verify Selected Day Details section
      expect(find.text('Detail Jadwal'), findsOneWidget);
      expect(find.text('Kamis, 12 November 2026'), findsOneWidget);
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Shift Regular Pagi'), findsOneWidget);
      expect(find.text('08:00 - 17:00'), findsOneWidget);

      // Verify Monthly Holidays section
      expect(find.text('Hari Libur Bulan Ini'), findsOneWidget);
      expect(find.text('Hari Pahlawan'), findsOneWidget);

      // Tap on day 10 (Hari Pahlawan - Holiday)
      // Note: 10 appears in the calendar grid and also in the holiday list, tap the calendar cell
      final day10Finders = find.text('10');
      expect(day10Finders, findsWidgets);
      await tester.tap(day10Finders.first);
      await tester.pumpAndSettle();

      // Now detail should show Hari Pahlawan holiday banner
      expect(find.text('Selasa, 10 November 2026'), findsOneWidget);
      expect(find.text('Hari Pahlawan'), findsWidgets);

      // Tap on day 15 (Off)
      final day15Finders = find.text('15');
      await tester.tap(day15Finders.first);
      await tester.pumpAndSettle();
      expect(find.text('Minggu, 15 November 2026'), findsOneWidget);
      expect(find.text('Libur Rutin'), findsWidgets);

      // Tap on day 18 (Cuti)
      final day18Finders = find.text('18');
      await tester.tap(day18Finders.first);
      await tester.pumpAndSettle();
      expect(find.text('Rabu, 18 November 2026'), findsOneWidget);
      expect(find.text('Cuti Tahunan'), findsOneWidget);

      // Tap on day 22 (No schedule)
      final day22Finders = find.text('22');
      await tester.tap(day22Finders.first);
      await tester.pumpAndSettle();
      expect(find.text('Minggu, 22 November 2026'), findsOneWidget);
      expect(find.text('Tidak ada jadwal roster khusus untuk tanggal ini.'), findsOneWidget);

      // Test Month switching button
      final nextMonthButton = find.byTooltip('Bulan berikutnya');
      expect(nextMonthButton, findsOneWidget);
      await tester.tap(nextMonthButton);
      await tester.pumpAndSettle();

      expect(find.text('Desember 2026'), findsOneWidget);

      // "Hari Ini" action button appears when not on today's month/day
      final todayButton = find.text('Hari Ini');
      expect(todayButton, findsWidgets);
      await tester.tap(todayButton.first);
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
    });

    testWidgets('renders error view with retry button when error occurs', (tester) async {
      final failingRepo = _MockHomeRepository();
      when(
        () => failingRepo.scheduleCalendar(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenThrow(Exception('Gagal mengambil jadwal'));

      final controller = ScheduleCalendarController(
        repository: failingRepo,
        today: () => DateTime.utc(2026, 11, 12),
      );

      Get.put<ScheduleCalendarController>(controller);

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: const ScheduleCalendarView(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });
}
