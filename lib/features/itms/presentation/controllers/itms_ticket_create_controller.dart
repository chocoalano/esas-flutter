import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/itms_service.dart';
import '../../data/repositories/itms_repository.dart';

/// Filing an IT ticket (ITMS-01).
///
/// "Lapor" on the dashboard used to open the dashboard again: the repository
/// could file a ticket and nothing on screen could. The rules below mirror
/// `ItmsTicketApiController::store` — a service, a subject of at most 255
/// characters, an optional description of at most 4000 — so a refusal is
/// explained before the request rather than after it.
class ItmsTicketCreateController extends GetxController {
  ItmsTicketCreateController({required ItmsRepository repository})
    : _repository = repository;

  final ItmsRepository _repository;

  // The server's own limit (ItmsTicketApiController `max:150`): a longer
  // subject passed here and was refused only after sending (FUNC-A03).
  static const int subjectMax = 150;
  static const int descriptionMax = 4000;

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString error = RxnString();
  final RxList<ItmsService> services = <ItmsService>[].obs;
  final RxnInt serviceId = RxnInt();

  final TextEditingController subjectC = TextEditingController();
  final TextEditingController descriptionC = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadServices();
  }

  @override
  void onClose() {
    subjectC.dispose();
    descriptionC.dispose();
    super.onClose();
  }

  /// Why the services could not be loaded, apart from a submit error, so the
  /// form offers a retry instead of an empty dropdown (UX-A07).
  final Rxn<ApiException> loadError = Rxn<ApiException>();

  Future<void> loadServices() async {
    isLoading.value = true;
    error.value = null;
    loadError.value = null;

    try {
      services.assignAll(await _repository.services());
      if (services.length == 1) serviceId.value = services.first.id;
    } on ApiException catch (e) {
      loadError.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  /// Why the form cannot be sent yet, or null when it can.
  String? validate() {
    if (serviceId.value == null) return 'Pilih layanan IT yang bermasalah.';

    final subject = subjectC.text.trim();
    if (subject.isEmpty) return 'Judul kendala wajib diisi.';
    if (subject.length > subjectMax) {
      return 'Judul paling banyak $subjectMax karakter.';
    }

    if (descriptionC.text.trim().length > descriptionMax) {
      return 'Uraian paling banyak $descriptionMax karakter.';
    }

    return null;
  }

  /// File the ticket. True when the server accepted it.
  ///
  /// The key of the ticket the user is trying to raise, and the content it
  /// was minted for: a retry of the same content reuses it, an edit mints a
  /// new one.
  String? _intentKey;
  String? _intentFingerprint;

  /// Guarded: a second tap while the first is on its way does nothing, and a
  /// retry of the same content - after a timeout too - carries the same
  /// Idempotency-Key, so the server answers it instead of raising a second
  /// ticket.
  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    final problem = validate();
    if (problem != null) {
      error.value = problem;
      return false;
    }

    error.value = null;
    isSubmitting.value = true;

    final description = descriptionC.text.trim();
    final fingerprint = [
      serviceId.value,
      subjectC.text.trim(),
      description,
    ].join('|');
    if (_intentFingerprint != fingerprint) {
      _intentKey = IdempotencyKey.mint();
      _intentFingerprint = fingerprint;
    }

    try {
      await _repository.createTicket(
        serviceId: serviceId.value!,
        subject: subjectC.text.trim(),
        description: description.isEmpty ? null : description,
        idempotencyKey: _intentKey,
      );
      _intentKey = null;
      _intentFingerprint = null;
      return true;
    } on ApiException catch (e) {
      error.value = e.firstFieldError ?? e.message;
      // A definite refusal ends the attempt; no answer (or a server fault)
      // keeps the key, because the ticket may already exist.
      if (e.status != null && e.status! < 500 && e.status != 429) {
        _intentKey = null;
        _intentFingerprint = null;
      }
      AppLogger.warning('ITMS ticket refused: ${e.code ?? e.status}');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
