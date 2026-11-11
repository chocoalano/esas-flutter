import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/schedule_calendar.dart';
import '../../data/repositories/home_repository.dart';

class ScheduleCalendarController extends GetxController {
  ScheduleCalendarController({required HomeRepository repository})
      : _repository = repository;

  final HomeRepository _repository;

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
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);

      final fromStr =
          "${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}";
      final toStr =
          "${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}";

      final result = await _repository.scheduleCalendar(from: fromStr, to: toStr);
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

