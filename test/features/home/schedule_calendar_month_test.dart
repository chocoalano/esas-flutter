import 'package:esas/core/tenancy/workspace_clock.dart';
import 'package:esas/features/home/data/models/schedule_calendar.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/controllers/schedule_calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

class _Repo extends Mock implements HomeRepository {}

class _Calendar extends Fake implements ScheduleCalendar {}

/// HOME-10. The range was the handset's month. A phone set to another zone —
/// or simply wrong — an hour either side of midnight on the 1st asked for the
/// month before or after the one the workspace is in.
void main() {
  late _Repo repo;

  setUp(() {
    Get.testMode = true;
    repo = _Repo();
    when(
      () => repo.scheduleCalendar(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => _Calendar());
  });

  tearDown(Get.reset);

  test('asks for the workspace month, first day to last', () async {
    final controller = ScheduleCalendarController(
      repository: repo,
      today: () => DateTime.utc(2028, 2, 1),
    );

    await controller.loadSchedule();

    verify(
      () => repo.scheduleCalendar(from: '2028-02-01', to: '2028-02-29'),
    ).called(1);
  });

  test('by default the day is the workspace clock\'s', () {
    // 00:30 on 1 March in Jakarta is still 28 February in UTC. The workspace
    // is in March, whatever zone the handset is in.
    final clock = WorkspaceClock.fallback();
    final wall = clock.wallClock(DateTime.utc(2027, 2, 28, 17, 30));

    expect(
      DateTime.utc(wall.year, wall.month, wall.day),
      DateTime.utc(2027, 3, 1),
    );
    expect(ScheduleCalendarController.monthRange(DateTime.utc(2027, 3, 1)), (
      '2027-03-01',
      '2027-03-31',
    ));
  });
}
