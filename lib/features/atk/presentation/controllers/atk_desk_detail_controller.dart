import 'dart:convert';

import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/atk_models.dart';
import '../../data/repositories/atk_repository.dart';
import 'atk_desk_list_controller.dart';

/// One request on the ATK desk, and the officer's actions on it: reserve,
/// reject, hand over — only those the server lists in `allowed_actions` — and
/// receiving goods back against a handover the server marks `can_return`.
///
/// **One logical action, one Idempotency-Key.** The key is minted the first
/// time an action with a given body is sent and reused for every retry of it,
/// including after a timeout, when the app cannot know whether the server
/// acted. A changed body (another reason, another quantity, a newer
/// `lock_version`) is a new action with a new key. The key is dropped once the
/// server has answered definitely.
///
/// Reserve and reject carry the `lock_version` the screen was drawn from, so a
/// request someone else changed meanwhile is refused (409) instead of
/// overwritten; the screen then reloads.
class AtkDeskDetailController extends GetxController {
  AtkDeskDetailController({
    required AtkRepository repository,
    required this.requestId,
  }) : _repository = repository;

  final AtkRepository _repository;
  final int requestId;

  /// What the server accepts as a rejection or return reason (`max:255`).
  static const int reasonMax = 255;

  /// What [submitting] holds while a return is on its way. Not one of the
  /// server's `allowed_actions`: a return is offered per handover.
  static const String returnAction = 'return';

  /// The server's code for a return of more than is still returnable.
  static const String exceedsIssuedCode = 'EXCEEDS_ISSUED_QUANTITY';

  final Rxn<AtkDeskDetail> detail = Rxn<AtkDeskDetail>();
  final RxBool isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  /// The action being sent, so its button shows progress and no second action
  /// starts meanwhile.
  final RxnString submitting = RxnString();

  /// What the last action ended in, when it did not simply succeed.
  final RxnString notice = RxnString();
  final RxBool noticeIsConflict = false.obs;

  final Map<String, String> _attemptKeys = {};

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// The account may not use the desk at all.
  bool get isDenied =>
      error.value?.isForbidden == true ||
      error.value?.code == 'DESK_NOT_ALLOWED';

  bool allows(String action) => detail.value?.request.allows(action) ?? false;

  Future<void> load() async {
    isLoading.value = detail.value == null;
    error.value = null;
    try {
      detail.value = await _repository.deskRequest(requestId);
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  String? validateReason(String reason) {
    final text = reason.trim();
    if (text.isEmpty) return 'Alasan penolakan wajib diisi.';
    if (text.length > reasonMax) {
      return 'Alasan paling banyak $reasonMax karakter.';
    }
    return null;
  }

  String? validateIssueQuantity(int? quantity) {
    final current = detail.value;
    if (quantity == null || quantity < 1) return 'Jumlah minimal 1.';
    if (current != null && quantity > current.remaining) {
      return 'Paling banyak ${current.remaining} ${current.request.unit}.';
    }
    return null;
  }

  String? validateReturnReason(String reason) {
    final text = reason.trim();
    if (text.isEmpty) return 'Alasan pengembalian wajib diisi.';
    if (text.length > reasonMax) {
      return 'Alasan paling banyak $reasonMax karakter.';
    }
    return null;
  }

  /// Between one and what handover [issueId] may still give back.
  String? validateReturnQuantity(int issueId, int? quantity) {
    final current = detail.value;
    final issue = current?.issueById(issueId);
    if (current == null || issue == null || !issue.isReturnable) {
      return 'Tidak ada lagi barang yang bisa dikembalikan dari penyerahan ini.';
    }
    if (quantity == null || quantity < 1) return 'Jumlah minimal 1.';
    if (quantity > issue.returnableQuantity) {
      return 'Paling banyak ${issue.returnableQuantity} ${current.request.unit}.';
    }
    return null;
  }

  Future<bool> reserve() => _run(AtkDeskAction.reserve, {
    if (detail.value?.request.lockVersion case final version?)
      'lock_version': version,
  });

  Future<bool> reject(String reason) {
    final problem = validateReason(reason);
    if (problem != null) {
      notice.value = problem;
      noticeIsConflict.value = false;
      return Future.value(false);
    }
    return _run(AtkDeskAction.reject, {
      'reason': reason.trim(),
      if (detail.value?.request.lockVersion case final version?)
        'lock_version': version,
    });
  }

  Future<bool> issue(int? quantity) {
    final problem = validateIssueQuantity(quantity);
    if (problem != null) {
      notice.value = problem;
      noticeIsConflict.value = false;
      return Future.value(false);
    }
    return _run(AtkDeskAction.issue, {'quantity': quantity});
  }

  /// Records [quantity] of handover [issueId] coming back, and why. Returns
  /// the server's sentence when it recorded it, or null; [notice] says why
  /// not.
  ///
  /// One intent, one key, as for the other actions: the same handover,
  /// quantity and reason sent again after a lost answer reuses it.
  Future<String?> returnItems(
    int issueId, {
    required int? quantity,
    required String reason,
  }) async {
    final problem =
        validateReturnQuantity(issueId, quantity) ??
        validateReturnReason(reason);
    if (problem != null) {
      notice.value = problem;
      noticeIsConflict.value = false;
      return null;
    }
    if (detail.value == null || submitting.value != null) return null;

    final text = reason.trim();
    final body = {'quantity': quantity, 'reason': text};
    final signature = '$returnAction|$issueId|${jsonEncode(body)}';
    final key = _attemptKeys.putIfAbsent(signature, IdempotencyKey.mint);

    submitting.value = returnAction;
    notice.value = null;
    noticeIsConflict.value = false;

    try {
      final recorded = await _repository.returnItems(
        requestId: requestId,
        issueId: issueId,
        quantity: quantity!,
        reason: text,
        idempotencyKey: key,
      );
      detail.value = recorded.detail;
      _attemptKeys.remove(signature);
      _refreshList();
      return recorded.message;
    } on ApiException catch (e) {
      await _settleFailure(
        e,
        signature,
        // The handover is not on this request; the request itself may be.
        missing: 'Penyerahan ini tidak ditemukan pada permintaan ini.',
      );
      return null;
    } finally {
      submitting.value = null;
    }
  }

  /// Sends [action] with [body]. Returns whether the server applied it.
  Future<bool> _run(String action, Map<String, dynamic> body) async {
    if (detail.value == null || submitting.value != null) return false;

    final signature = '$action|${jsonEncode(body)}';
    final key = _attemptKeys.putIfAbsent(signature, IdempotencyKey.mint);

    submitting.value = action;
    notice.value = null;
    noticeIsConflict.value = false;

    try {
      detail.value = await _repository.deskAct(
        requestId,
        action,
        body,
        idempotencyKey: key,
      );
      _attemptKeys.remove(signature);
      _refreshList();
      return true;
    } on ApiException catch (e) {
      await _settleFailure(e, signature);
      return false;
    } finally {
      submitting.value = null;
    }
  }

  /// [missing] is what a 404 says when it concerns part of the request; by
  /// default a 404 means the request itself is gone.
  Future<void> _settleFailure(
    ApiException e,
    String signature, {
    String? missing,
  }) async {
    // No answer, or a server fault: the action may or may not have happened.
    // Keep the key, so sending again cannot act twice, and read the request
    // back to see where it stands.
    if (e.isTransportFailure || (e.status ?? 0) >= 500 || e.status == 429) {
      notice.value =
          'Hasil belum pasti (${e.message}). Data dimuat ulang; bila belum '
          'berubah, kirim ulang — sistem tidak akan mencatatnya dua kali.';
      await load();
      return;
    }

    if (e.code == 'idempotency_in_progress') {
      notice.value = 'Permintaan yang sama masih diproses. Coba lagi sebentar.';
      return;
    }

    _attemptKeys.remove(signature);

    if (e.code == exceedsIssuedCode) {
      // Someone recorded a return meanwhile: show what is left.
      noticeIsConflict.value = true;
      notice.value = 'Jumlah melebihi barang yang masih bisa dikembalikan.';
      await load();
      return;
    }

    if (e.status == 409) {
      // STALE_VERSION / INVALID_TRANSITION: someone else moved it.
      noticeIsConflict.value = true;
      notice.value = 'Data berubah, dimuat ulang.';
      await load();
      return;
    }

    if (e.status == 404) {
      if (missing == null) {
        error.value = e;
        return;
      }
      notice.value = missing;
      await load();
      return;
    }

    if (e.isForbidden) {
      notice.value = 'Anda tidak berhak melakukan tindakan ini.';
      await load();
      return;
    }

    notice.value = e.firstFieldError ?? e.message;
  }

  void _refreshList() {
    if (Get.isRegistered<AtkDeskListController>()) {
      Get.find<AtkDeskListController>().load();
    }
  }
}
