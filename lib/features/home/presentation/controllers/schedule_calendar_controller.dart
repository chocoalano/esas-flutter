import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/tenancy/workspace_clock.dart';
import '../../data/models/schedule_calendar.dart';
import '../../data/repositories/home_repository.dart';

class ScheduleCalendarController extends GetxController {
  ScheduleCalendarController({
    required HomeRepository repository,
    DateTime Function()? today,
  }) : _repository = repository,
       _today = today ?? (() => WorkspaceClock.current.today()) {
    final now = _today();
    currentMonth = DateTime.utc(now.year, now.month, 1).obs;
    selectedDate = DateTime.utc(now.year, now.month, now.day).obs;
  }

  final HomeRepository _repository;

  /// The workspace's date, not the handset's (HOME-10). A seam so the month
  /// can be pinned in a test; the app always uses the workspace clock.
  final DateTime Function() _today;

  /// Bulan yang sedang ditampilkan di kalender (dinormalisasi ke tanggal 1 UTC).
  late final Rx<DateTime> currentMonth;

  /// Tanggal yang sedang dipilih pengguna untuk melihat detail shift & libur.
  late final Rx<DateTime> selectedDate;

  /// The first and last day of [day]'s month, as the API wants them.
  static (String, String) monthRange(DateTime day) {
    String iso(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return (
      iso(DateTime(day.year, day.month, 1)),
      iso(DateTime(day.year, day.month + 1, 0)),
    );
  }

  static String isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final Rxn<ScheduleCalendar> calendar = Rxn<ScheduleCalendar>();

  /// Lookup cepat berdasar string format 'YYYY-MM-DD'.
  final RxMap<String, ScheduleCalendarItem> scheduleMap =
      <String, ScheduleCalendarItem>{}.obs;
  final RxMap<String, ScheduleHoliday> holidayMap =
      <String, ScheduleHoliday>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadSchedule();
  }

  DateTime get today => _today();

  /// Key tanggal untuk hari yang sedang dipilih.
  String get selectedDateKey => isoDate(selectedDate.value);

  /// Item jadwal untuk tanggal yang dipilih.
  ScheduleCalendarItem? get selectedSchedule => scheduleMap[selectedDateKey];

  /// Hari libur untuk tanggal yang dipilih.
  ScheduleHoliday? get selectedHoliday => holidayMap[selectedDateKey];

  /// Ambil jadwal untuk tanggal tertentu.
  ScheduleCalendarItem? scheduleFor(DateTime date) => scheduleMap[isoDate(date)];

  /// Ambil libur untuk tanggal tertentu.
  ScheduleHoliday? holidayFor(DateTime date) => holidayMap[isoDate(date)];

  Future<void> loadSchedule([DateTime? targetMonth]) async {
    if (targetMonth != null) {
      currentMonth.value = DateTime.utc(targetMonth.year, targetMonth.month, 1);
    }

    isLoading.value = true;
    error.value = null;

    try {
      // The workspace's month, not the handset's (HOME-10): a phone an hour
      // the wrong side of midnight on the 1st asked for the wrong month.
      final (from, to) = monthRange(currentMonth.value);

      final result = await _repository.scheduleCalendar(from: from, to: to);
      calendar.value = result;

      // Isi peta lookup
      final newScheduleMap = <String, ScheduleCalendarItem>{};
      for (final item in _safeSchedule(result)) {
        newScheduleMap[item.date] = item;
      }
      scheduleMap.assignAll(newScheduleMap);

      final newHolidayMap = <String, ScheduleHoliday>{};
      for (final holiday in _safeHolidays(result)) {
        newHolidayMap[holiday.date] = holiday;
      }
      holidayMap.assignAll(newHolidayMap);

      // Pastikan tanggal terpilih tetap sinkron dengan bulan aktif
      final current = selectedDate.value;
      if (current.year != currentMonth.value.year ||
          current.month != currentMonth.value.month) {
        final td = _today();
        if (td.year == currentMonth.value.year &&
            td.month == currentMonth.value.month) {
          selectedDate.value = DateTime.utc(td.year, td.month, td.day);
        } else {
          selectedDate.value = DateTime.utc(
            currentMonth.value.year,
            currentMonth.value.month,
            1,
          );
        }
      }
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void selectDate(DateTime date) {
    selectedDate.value = DateTime.utc(date.year, date.month, date.day);
    if (date.year != currentMonth.value.year ||
        date.month != currentMonth.value.month) {
      loadSchedule(date);
    }
  }

  void previousMonth() {
    final prev = DateTime.utc(
      currentMonth.value.year,
      currentMonth.value.month - 1,
      1,
    );
    loadSchedule(prev);
  }

  void nextMonth() {
    final next = DateTime.utc(
      currentMonth.value.year,
      currentMonth.value.month + 1,
      1,
    );
    loadSchedule(next);
  }

  void goToToday() {
    final td = _today();
    selectedDate.value = DateTime.utc(td.year, td.month, td.day);
    if (currentMonth.value.year != td.year ||
        currentMonth.value.month != td.month) {
      loadSchedule(td);
    }
  }

  static List<ScheduleCalendarItem> _safeSchedule(ScheduleCalendar cal) {
    try {
      return cal.schedule;
    } catch (_) {
      return const [];
    }
  }

  static List<ScheduleHoliday> _safeHolidays(ScheduleCalendar cal) {
    try {
      return cal.holidays;
    } catch (_) {
      return const [];
    }
  }
}
