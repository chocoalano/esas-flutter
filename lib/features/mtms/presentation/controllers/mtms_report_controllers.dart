import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/mtms_reports.dart';

/// The employee's own damage reports (FUNC-D02).
class MtmsReportListController extends GetxController {
  MtmsReportListController({required MtmsReportsRepository repository})
    : _repository = repository;

  final MtmsReportsRepository _repository;

  final RxList<MtmsReport> reports = <MtmsReport>[].obs;
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
      final first = await _repository.reports();
      _page = 1;
      reports.assignAll(first.reports);
      hasMore.value = first.lastPage > 1;
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
      final next = await _repository.reports(page: _page + 1);
      _page++;
      reports.addAll(next.reports);
      hasMore.value = next.lastPage > _page;
    } on ApiException catch (e) {
      error.value = e;
    } finally {
      isLoadingMore.value = false;
    }
  }
}

/// Filing one damage report (FUNC-D02).
///
/// One report per intent: a second tap while the first is on its way does
/// nothing, and a retry of the same content after a lost answer reuses the
/// same Idempotency-Key, so the server answers it once.
class MtmsReportCreateController extends GetxController {
  MtmsReportCreateController({required MtmsReportsRepository repository})
    : _repository = repository;

  final MtmsReportsRepository _repository;

  static const int symptomMax = 2000;

  final RxList<MtmsEquipment> equipment = <MtmsEquipment>[].obs;
  final RxnInt equipmentId = RxnInt();
  final RxString severity = 'normal'.obs;
  final TextEditingController symptomC = TextEditingController();

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString error = RxnString();
  final Rxn<ApiException> loadError = Rxn<ApiException>();

  String? _intentKey;
  String? _intentFingerprint;

  @override
  void onInit() {
    super.onInit();
    loadEquipment();
  }

  @override
  void onClose() {
    symptomC.dispose();
    super.onClose();
  }

  Future<void> loadEquipment() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      equipment.assignAll(await _repository.equipment());
    } on ApiException catch (e) {
      loadError.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  String? validate() {
    if (equipmentId.value == null) return 'Pilih peralatan yang rusak.';
    final symptom = symptomC.text.trim();
    if (symptom.isEmpty) return 'Tuliskan gejala kerusakannya.';
    if (symptom.length > symptomMax) {
      return 'Gejala paling banyak $symptomMax karakter.';
    }
    return null;
  }

  /// The report number when the server accepted it, or null.
  Future<String?> submit() async {
    if (isSubmitting.value) return null;

    final problem = validate();
    if (problem != null) {
      error.value = problem;
      return null;
    }

    error.value = null;
    isSubmitting.value = true;

    final fingerprint =
        '${equipmentId.value}|${severity.value}|${symptomC.text.trim()}';
    if (_intentFingerprint != fingerprint) {
      _intentKey = IdempotencyKey.mint();
      _intentFingerprint = fingerprint;
    }

    try {
      final filed = await _repository.file(
        equipmentId: equipmentId.value!,
        symptom: symptomC.text.trim(),
        severity: severity.value,
        idempotencyKey: _intentKey!,
      );
      _intentKey = null;
      _intentFingerprint = null;
      return filed.number;
    } on ApiException catch (e) {
      error.value = e.firstFieldError ?? e.message;
      // A definite answer ends the attempt; a lost one keeps the key so the
      // retry cannot file a second report.
      if (e.status != null && e.status! < 500 && e.status != 429) {
        _intentKey = null;
        _intentFingerprint = null;
      }
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }
}
