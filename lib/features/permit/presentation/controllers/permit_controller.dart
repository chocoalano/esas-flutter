import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/models/leave_type.dart';
import '../../data/repositories/permit_repository.dart';

/// The permit-type picker.
class PermitController extends GetxController {
  PermitController({required PermitRepository repository})
    : _repository = repository;

  final PermitRepository _repository;

  final isLoading = false.obs;
  final RxList<LeaveType> leaveTypes = <LeaveType>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchLeaveTypes();
  }

  Future<void> fetchLeaveTypes() async {
    isLoading.value = true;

    try {
      leaveTypes.assignAll(await _repository.leaveTypes());
    } on ApiException catch (error) {
      showErrorSnackbar('Gagal memuat jenis perizinan: ${error.message}');
    } finally {
      isLoading.value = false;
    }
  }
}
