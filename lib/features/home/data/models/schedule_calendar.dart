import '../../../../core/utils/json_parsers.dart';

/// Kalender jadwal kerja karyawan.
class ScheduleCalendar {
  const ScheduleCalendar({
    required this.from,
    required this.to,
    required this.holidays,
    required this.schedule,
  });

  factory ScheduleCalendar.fromJson(Map<String, dynamic> json) {
    return ScheduleCalendar(
      from: asString(json['from']) ?? '',
      to: asString(json['to']) ?? '',
      holidays: asList(json['holidays'])
          .map((item) => ScheduleHoliday.fromJson(asObject(item)))
          .toList(),
      schedule: asList(json['schedule'])
          .map((item) => ScheduleCalendarItem.fromJson(asObject(item)))
          .toList(),
    );
  }

  final String from;
  final String to;
  final List<ScheduleHoliday> holidays;
  final List<ScheduleCalendarItem> schedule;
}

/// Item jadwal kerja untuk satu hari tertentu.
class ScheduleCalendarItem {
  const ScheduleCalendarItem({
    required this.date,
    this.shift,
    this.startsAt,
    this.endsAt,
    required this.dayType,
  });

  factory ScheduleCalendarItem.fromJson(Map<String, dynamic> json) {
    return ScheduleCalendarItem(
      date: asString(json['date']) ?? '',
      shift: asString(json['shift']),
      startsAt: asString(json['starts_at']),
      endsAt: asString(json['ends_at']),
      dayType: asString(json['day_type']) ?? 'workday',
    );
  }

  final String date;
  final String? shift;
  final String? startsAt;
  final String? endsAt;
  final String dayType;

  bool get isDayOff => dayType == 'day_off' || dayType == 'off';
  bool get isHoliday => dayType == 'holiday' || dayType == 'public_holiday';
  bool get isWorkday => !isDayOff && !isHoliday;
}

/// Hari libur kalender kerja perusahaan.
class ScheduleHoliday {
  const ScheduleHoliday({
    required this.date,
    required this.name,
    required this.type,
  });

  factory ScheduleHoliday.fromJson(Map<String, dynamic> json) {
    return ScheduleHoliday(
      date: asString(json['date']) ?? '',
      name: asString(json['name']) ?? '',
      type: asString(json['type']) ?? 'holiday',
    );
  }

  final String date;
  final String name;
  final String type;
}

