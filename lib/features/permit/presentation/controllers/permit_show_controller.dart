import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/json_parsers.dart';
import '../../data/models/leave_list.dart';
import '../../data/models/leave_type.dart';
import '../../data/repositories/permit_repository.dart';

class PermitShowController extends GetxController {
  PermitShowController({required PermitRepository repository})
    : _repository = repository;

  final PermitRepository _repository;

  final RxBool isLoading = true.obs;
  final Rx<Permit?> permit = Rx<Permit?>(null);
  final RxBool canApprove = false.obs;
  final Rx<Approval?> myApproval = Rx<Approval?>(null);
  final permitId = 0.obs;
  final permitType = Rx<LeaveType?>(null);

  int get currentUserId => _repository.currentUserId ?? 0;

  @override
  void onInit() {
    super.onInit();

    _readArguments();
    ever(permit, (_) => _evaluateApproval());
    loadPermitDetails();
  }

  void _readArguments() {
    final args = Get.arguments;

    if (args is! Map) {
      return;
    }

    final incoming = args['permit'];

    if (incoming is Permit) {
      permitType.value = incoming.permitType;
    }

    // `asInt` rather than `as int?`: an id arriving from an FCM payload is a
    // string, and the cast would have thrown.
    permitId.value = asInt(args['id']) ?? 0;
  }

  Future<void> loadPermitDetails() async {
    if (permitId.value <= 0) {
      isLoading.value = false;
      return;
    }

    isLoading.value = true;

    try {
      permit.value = await _repository.detail(permitId.value);
    } on ApiException catch (error) {
      permit.value = null;
      showErrorSnackbar('Gagal mengambil detail perizinan: ${error.message}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Work out whether this employee is one of the approvers, and still owes a
  /// decision.
  void _evaluateApproval() {
    final current = permit.value;

    if (current == null) {
      myApproval.value = null;
      canApprove.value = false;
      return;
    }

    final mine = current.approvals.firstWhereOrNull(
      (a) => a.userId == currentUserId,
    );

    myApproval.value = mine;
    // `'w'` is waiting. The original dereferenced `userApprove!` here, which
    // throws on an approval row that has not been populated yet.
    canApprove.value = mine != null && mine.userApprove?.toLowerCase() == 'w';
  }

  Future<void> submitApproval({required bool approve, String? notes}) async {
    final approval = myApproval.value;
    final approvalId = approval?.id;

    if (approvalId == null) {
      showErrorSnackbar(
        'Tidak ada peran persetujuan untuk Anda pada perizinan ini.',
      );
      return;
    }

    isLoading.value = true;

    try {
      await _repository.approve(
        permitId: permitId.value,
        approve: approve,
        notes: notes,
      );

      showSuccessSnackbar(
        approve
            ? 'Persetujuan berhasil dikirim.'
            : 'Penolakan berhasil dikirim.',
      );

      await loadPermitDetails();
    } on ApiException catch (error) {
      showErrorSnackbar(error.message);
    } finally {
      isLoading.value = false;
    }
  }
}
