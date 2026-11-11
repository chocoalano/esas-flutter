import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
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

  static const int subjectMax = 255;
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

  Future<void> loadServices() async {
    isLoading.value = true;
    error.value = null;

    try {
      services.assignAll(await _repository.services());
      if (services.length == 1) serviceId.value = services.first.id;
    } on ApiException catch (e) {
      error.value = e.message;
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
  /// Guarded: a second tap while the first is on its way does nothing. The
  /// endpoint takes no Idempotency-Key, so the guard is the only thing between
  /// a double tap and two tickets.
  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    final problem = validate();
    if (problem != null) {
      error.value = problem;
      return false;
    }

    error.value = null;
    isSubmitting.value = true;

    try {
      final description = descriptionC.text.trim();
      await _repository.createTicket(
        serviceId: serviceId.value!,
        subject: subjectC.text.trim(),
        description: description.isEmpty ? null : description,
      );
      return true;
    } on ApiException catch (e) {
      error.value = e.firstFieldError ?? e.message;
      AppLogger.warning('ITMS ticket refused: ${e.code ?? e.status}');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}
