import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/atk_models.dart';
import '../../data/repositories/atk_repository.dart';
import 'atk_request_list_controller.dart';

/// One of the requester's ATK requests, and confirming each handover.
///
/// One confirmation per handover, one Idempotency-Key per confirmation: the
/// key is kept through a retry after a lost answer and dropped once the server
/// has answered definitely. Confirming twice is answered with the first
/// confirmation by the server anyway.
class AtkRequestDetailController extends GetxController {
  AtkRequestDetailController({
    required AtkRepository repository,
    required this.requestId,
  }) : _repository = repository;

  final AtkRepository _repository;
  final int requestId;

  final Rxn<AtkRequestDetail> detail = Rxn<AtkRequestDetail>();
  final RxBool isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  /// The handover whose confirmation is on its way.
  final RxnInt acknowledging = RxnInt();

  /// Why the last confirmation did not go through.
  final RxnString notice = RxnString();

  final Map<int, String> _ackKeys = {};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = detail.value == null;
    error.value = null;
    try {
      detail.value = await _repository.request(requestId);
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  /// Confirms receiving handover [issueId]. Returns whether the server
  /// recorded it; on failure what is on screen stays and [notice] says why.
  Future<bool> acknowledge(int issueId) async {
    if (acknowledging.value != null || detail.value == null) return false;

    final key = _ackKeys.putIfAbsent(issueId, IdempotencyKey.mint);
    acknowledging.value = issueId;
    notice.value = null;

    try {
      detail.value = await _repository.acknowledge(
        requestId: requestId,
        issueId: issueId,
        idempotencyKey: key,
      );
      _ackKeys.remove(issueId);
      _refreshList();
      return true;
    } on ApiException catch (e) {
      if (e.isTransportFailure || (e.status ?? 0) >= 500 || e.status == 429) {
        notice.value =
            'Konfirmasi belum pasti terkirim (${e.message}). Coba lagi — '
            'sistem tidak akan mencatatnya dua kali.';
      } else if (e.code == 'idempotency_in_progress') {
        notice.value =
            'Konfirmasi yang sama masih diproses. Coba lagi sebentar.';
      } else {
        _ackKeys.remove(issueId);
        notice.value = e.isForbidden
            ? 'Anda tidak berhak mengonfirmasi penyerahan ini.'
            : e.message;
      }
      return false;
    } finally {
      acknowledging.value = null;
    }
  }

  void _refreshList() {
    if (Get.isRegistered<AtkRequestListController>()) {
      Get.find<AtkRequestListController>().load();
    }
  }
}
