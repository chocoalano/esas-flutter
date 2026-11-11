import 'package:esas/features/home/data/models/schedule_calendar.dart';
import 'package:esas/features/home/presentation/widgets/today_work_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // HOME-12. The clock-in time is the server's, "now" the handset's. A phone
  // three minutes slow wrapped the small negative into "23j 58m".
  group('worked minutes', () {
    test('a handset slightly behind the server reads as just started', () {
      expect(
        TodayWorkCard.workedMinutes(timeIn: '08:01', timeOut: null, now: 479),
        0,
      );
    });

    test('a night shift past midnight still counts across it', () {
      expect(
        TodayWorkCard.workedMinutes(timeIn: '22:00', timeOut: null, now: 60),
        180,
      );
    });
  });

  // HOME-11. Only two spellings were known and anything else — "leave",
  // "PUBLIC_HOLIDAY" — was drawn as an ordinary working day.
  group('calendar day types', () {
    ScheduleCalendarItem day(String type) =>
        ScheduleCalendarItem.fromJson({'date': '2026-11-12', 'day_type': type});

    test('spelling and case do not matter', () {
      expect(day('PUBLIC_HOLIDAY').isHoliday, isTrue);
      expect(day('national_holiday').isHoliday, isTrue);
      expect(day(' Day_Off ').isDayOff, isTrue);
    });

    test('leave is its own kind of day', () {
      expect(day('leave').isLeave, isTrue);
      expect(day('leave').isWorkday, isFalse);
    });

    test('an unknown kind is not claimed to be a working day', () {
      expect(day('training').isWorkday, isFalse);
      expect(day('workday').isWorkday, isTrue);
    });
  });
}
