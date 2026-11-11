import 'package:esas/features/home/data/models/schedule_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleCalendar model tests', () {
    test('parses schedule calendar json correctly', () {
      final json = {
        'from': '2026-11-01',
        'to': '2026-11-30',
        'holidays': [
          {
            'date': '2026-11-10',
            'name': 'Hari Pahlawan',
            'type': 'holiday',
          }
        ],
        'schedule': [
          {
            'date': '2026-11-10',
            'shift': 'Libur Nasional',
            'starts_at': null,
            'ends_at': null,
            'day_type': 'holiday',
          },
          {
            'date': '2026-11-11',
            'shift': 'Shift Pagi',
            'starts_at': '08:00',
            'ends_at': '17:00',
            'day_type': 'workday',
          },
          {
            'date': '2026-11-15',
            'shift': 'Off',
            'starts_at': null,
            'ends_at': null,
            'day_type': 'day_off',
          }
        ]
      };

      final calendar = ScheduleCalendar.fromJson(json);

      expect(calendar.from, '2026-11-01');
      expect(calendar.to, '2026-11-30');
      expect(calendar.holidays.length, 1);
      expect(calendar.holidays.first.name, 'Hari Pahlawan');

      expect(calendar.schedule.length, 3);
      final holidayItem = calendar.schedule[0];
      expect(holidayItem.isHoliday, isTrue);
      expect(holidayItem.isWorkday, isFalse);

      final workItem = calendar.schedule[1];
      expect(workItem.isWorkday, isTrue);
      expect(workItem.shift, 'Shift Pagi');
      expect(workItem.startsAt, '08:00');

      final offItem = calendar.schedule[2];
      expect(offItem.isDayOff, isTrue);
    });
  });
}

