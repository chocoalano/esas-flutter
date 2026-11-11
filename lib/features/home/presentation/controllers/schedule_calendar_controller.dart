import 'package:get/get.dart';

import '../../../../core/tenancy/workspace_clock.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/schedule_calendar.dart';
import '../../data/repositories/home_repository.dart';

class ScheduleCalendarController extends GetxController {
  ScheduleCalendarController({
    required HomeRepository repository,
    DateTime Function()? today,
  }) : _repository = repository,
       _today = today ?? (() => WorkspaceClock.current.today());

  final HomeRepository _repository;

  /// The workspace's date, not the handset's (HOME-10). A seam so the month
  /// can be pinned in a test; the app always uses the workspace clock.
  final DateTime Function() _today;

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

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final Rxn<ScheduleCalendar> calendar = Rxn<ScheduleCalendar>();

  @override
  void onInit() {
    super.onInit();
    loadSchedule();
  }

  Future<void> loadSchedule() async {
    isLoading.value = true;
    error.value = null;

    try {
      // The workspace's month, not the handset's (HOME-10): a phone an hour
      // the wrong side of midnight on the 1st asked for the wrong month.
      final (from, to) = monthRange(_today());

      final result = await _repository.scheduleCalendar(from: from, to: to);
      calendar.value = result;
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
