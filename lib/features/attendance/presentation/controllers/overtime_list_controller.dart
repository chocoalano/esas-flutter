import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/models/overtime_entry.dart';
import '../../data/repositories/attendance_repository.dart';

class OvertimeListController extends GetxController {
  OvertimeListController({required AttendanceRepository repository})
      : _repository = repository;

  final AttendanceRepository _repository;

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();
  final RxList<OvertimeEntry> items = <OvertimeEntry>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadOvertime();
  }

  Future<void> loadOvertime() async {
    isLoading.value = true;
    error.value = null;

    try {
      final result = await _repository.overtime();
      items.assignAll(result);
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

