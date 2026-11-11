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
      holidays: asList(
        json['holidays'],
      ).map((item) => ScheduleHoliday.fromJson(asObject(item))).toList(),
      schedule: asList(
        json['schedule'],
      ).map((item) => ScheduleCalendarItem.fromJson(asObject(item))).toList(),
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

  /// `day_type` as compared: trimmed, lower case (HOME-11). Only two exact
  /// spellings used to be known, and anything else was drawn as a workday.
  String get _type => dayType.trim().toLowerCase();

  bool get isDayOff =>
      const {'day_off', 'off', 'rest', 'rest_day'}.contains(_type);

  bool get isHoliday =>
      const {'holiday', 'public_holiday', 'national_holiday'}.contains(_type);

  bool get isLeave => const {'leave', 'cuti', 'on_leave'}.contains(_type);

  /// A working day only when the server says so — an unknown kind is not
  /// claimed to be one.
  bool get isWorkday =>
      // `working` is what the server sends (DayType) — UAT review H5.
      const {'working', 'workday', 'work', 'working_day', ''}.contains(_type);
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
