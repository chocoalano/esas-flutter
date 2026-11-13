import 'package:get/get.dart';

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

  /// Why the types could not be loaded. Kept, so a network failure is shown
  /// as one - with a retry - and not as "no leave types, ask HR" (UX-C08).
  final Rxn<ApiException> loadError = Rxn<ApiException>();

  @override
  void onInit() {
    super.onInit();
    fetchLeaveTypes();
  }

  Future<void> fetchLeaveTypes() async {
    isLoading.value = true;
    loadError.value = null;

    try {
      leaveTypes.assignAll(await _repository.leaveTypes());
    } on ApiException catch (error) {
      loadError.value = error;
    } finally {
      isLoading.value = false;
    }
  }
}
