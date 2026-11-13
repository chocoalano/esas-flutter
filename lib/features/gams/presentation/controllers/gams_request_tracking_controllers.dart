import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/gams_service_request.dart';
import '../../data/repositories/gams_repository.dart';

/// Every GA service request the employee raised, newest first (FUNC-D05).
/// The dashboard shows three; older ones could not be found at all.
class GamsRequestListController extends GetxController {
  GamsRequestListController({required GamsRepository repository})
    : _repository = repository;

  final GamsRepository _repository;

  static const int pageSize = 20;

  final RxList<GamsServiceRequest> requests = <GamsServiceRequest>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final first = await _repository.serviceRequests(page: 1);
      _page = 1;
      requests.assignAll(first);
      hasMore.value = first.length >= pageSize;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      final next = await _repository.serviceRequests(page: _page + 1);
      _page++;
      requests.addAll(next);
      hasMore.value = next.length >= pageSize;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoadingMore.value = false;
    }
  }
}

/// One of the employee's GA service requests, read fresh (FUNC-D05).
class GamsRequestDetailController extends GetxController {
  GamsRequestDetailController({
    required GamsRepository repository,
    required this.requestId,
  }) : _repository = repository;

  final GamsRepository _repository;
  final int requestId;

  final Rxn<GamsServiceRequest> request = Rxn<GamsServiceRequest>();
  final RxBool isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  final RxBool isCancelling = false.obs;

  String? _cancelKey;
  String? _cancelReason;

  /// Withdraws the request (D-06). Null when it went through; otherwise the
  /// message to show, with the dialog - and the reason - kept open. A lost
  /// answer keeps the Idempotency-Key, so a retry cannot cancel twice.
  Future<String?> cancel(String reason) async {
    if (isCancelling.value) return null;
    isCancelling.value = true;
    if (_cancelReason != reason) {
      _cancelKey = IdempotencyKey.mint();
      _cancelReason = reason;
    }
    try {
      await _repository.cancelServiceRequest(
        requestId,
        reason: reason,
        idempotencyKey: _cancelKey,
      );
      _cancelKey = null;
      _cancelReason = null;
      await load();
      return null;
    } on ApiException catch (e) {
      final settled = e.status != null && e.status! < 500 && e.status != 429;
      if (settled) {
        _cancelKey = null;
        _cancelReason = null;
        await load();
      }
      return e.message;
    } finally {
      isCancelling.value = false;
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      request.value = await _repository.serviceRequest(requestId);
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }
}
