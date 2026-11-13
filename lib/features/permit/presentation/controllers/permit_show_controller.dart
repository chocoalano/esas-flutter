import 'package:get/get.dart';

import '../../../../core/ui/dialogs/app_snackbar.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
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

  /// One controller per permit on the stack (PRMT-09).
  ///
  /// A notification for permit B, tapped while A is open, pushes a second
  /// detail screen. Registered without a tag, the second screen was handed A's
  /// controller — `lazyPut` of a registered type does nothing — and showed A,
  /// and approved A. The binding, the page and the view all derive the tag
  /// from the route's arguments, so each screen finds its own.
  static String tagFor(Object? arguments) {
    final id = arguments is Map ? asInt(arguments['id']) : null;

    return id == null ? 'permit' : 'permit-$id';
  }

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
  ///
  /// The tier the server marks `is_current`, not the first row with this
  /// person's id (PRMT-04). In a small company the line approver and the
  /// manager are often the same person: their first row is the one they have
  /// already answered, and the request then waits on their second, which the
  /// old lookup never reached — the screen said "already approved" and the
  /// request stalled.
  void _evaluateApproval() {
    final current = permit.value;

    if (current == null) {
      myApproval.value = null;
      canApprove.value = false;
      return;
    }

    final mine = current.approvals
        .where((a) => a.userId == currentUserId)
        .toList();
    final serverSaysWhich = current.approvals.any((a) => a.isCurrent != null);

    final owed = serverSaysWhich
        ? mine.firstWhereOrNull((a) => a.isCurrent == true && a.isWaiting)
        // A server that predates `is_current`: the first tier still waiting.
        : mine.firstWhereOrNull((a) => a.isWaiting);

    // Nothing owed: show what this person last decided, if anything.
    myApproval.value =
        owed ?? mine.where((a) => !a.isWaiting).lastOrNull ?? mine.firstOrNull;
    canApprove.value = owed != null;
  }

  /// The attachment is being fetched.
  final RxBool isDownloading = false.obs;

  /// Fetch this permit's attachment through the session (PRMT-03).
  ///
  /// The file is private to the tenant; opening it by a public address used
  /// to fail for exactly the approver who had to read it.
  Future<PermitAttachment?> downloadAttachment() async {
    final file = permit.value?.file;

    if (file == null || file.isEmpty || isDownloading.value) return null;

    isDownloading.value = true;

    try {
      return await _repository.attachment(permitId: permitId.value, file: file);
    } on ApiException catch (error) {
      showErrorSnackbar(error.message);
      return null;
    } finally {
      isDownloading.value = false;
    }
  }

  /// A decision is being sent. Both buttons wait for it (PRMT-01).
  final RxBool isSubmitting = false.obs;

  _DecisionIntent? _intent;

  /// Send this person's decision on the tier they owe.
  ///
  /// One decision is one request (PRMT-01). The key is minted once per
  /// decision and kept while the outcome is unknown — a timeout, a server
  /// error, a request the server says is still in progress — so trying again
  /// is the same request, which the server replays instead of applying to the
  /// next tier this same person may also hold.
  /// True when the decision was recorded. The reject sheet stays open,
  /// with the reason in it, until then (UX-C12).
  Future<bool> submitApproval({required bool approve, String? notes}) async {
    if (isSubmitting.value) return false;

    final approval = myApproval.value;
    final approvalId = approval?.id;

    if (approvalId == null || !canApprove.value) {
      showErrorSnackbar(
        'Tidak ada peran persetujuan untuk Anda pada perizinan ini.',
      );
      return false;
    }

    isSubmitting.value = true;

    try {
      var intent = _intent;

      if (intent != null && !intent.isSameAs(approvalId, approve, notes)) {
        // A different decision while an earlier one may already have been
        // recorded. Find out first: if it was, the tier has moved and this
        // decision would land on the next one.
        await loadPermitDetails();
        _intent = null;

        if (!canApprove.value || myApproval.value?.id != approvalId) {
          showWarningSnackbar(
            'Status pengajuan sudah berubah. Periksa kembali sebelum '
            'memutuskan.',
          );
          return false;
        }

        intent = null;
      }

      intent ??= _DecisionIntent(
        approvalId: approvalId,
        approve: approve,
        notes: notes,
        key: IdempotencyKey.mint(),
      );
      _intent = intent;

      await _repository.approve(
        permitId: permitId.value,
        approve: approve,
        notes: notes,
        idempotencyKey: intent.key,
      );

      _intent = null;

      showSuccessSnackbar(
        approve
            ? 'Persetujuan berhasil dikirim.'
            : 'Penolakan berhasil dikirim.',
      );

      await loadPermitDetails();
      return true;
    } on ApiException catch (error) {
      showErrorSnackbar(error.message);

      if (!_outcomeUnknown(error)) {
        // The server's final word. Let go of the key, and show the request as
        // it now stands rather than a bar that will be refused again.
        _intent = null;
        await loadPermitDetails();
      }
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Whether the decision may have been recorded although no answer said so.
  static bool _outcomeUnknown(ApiException error) =>
      error.isTransportFailure ||
      (error.status ?? 0) >= 500 ||
      error.status == 429 ||
      error.code == 'idempotency_in_progress';
}

class _DecisionIntent {
  const _DecisionIntent({
    required this.approvalId,
    required this.approve,
    required this.notes,
    required this.key,
  });

  final int approvalId;
  final bool approve;
  final String? notes;
  final String key;

  bool isSameAs(int approvalId, bool approve, String? notes) =>
      this.approvalId == approvalId &&
      this.approve == approve &&
      (this.notes ?? '') == (notes ?? '');
}
