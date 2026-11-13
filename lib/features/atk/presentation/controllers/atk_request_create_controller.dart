import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/atk_models.dart';
import '../../data/repositories/atk_repository.dart';

/// Asking GA for office supplies (ATK).
///
/// **One request per intent.** A second tap while the first is on its way does
/// nothing. A retry of the same content after a lost answer (no reply, 5xx,
/// 429) reuses the same Idempotency-Key, so the server answers it once instead
/// of filing a second request. A definite refusal (any other 4xx) ends the
/// attempt: the next send is a new intent with a new key. Changed content is a
/// new intent too.
class AtkRequestCreateController extends GetxController {
  AtkRequestCreateController({required AtkRepository repository})
    : _repository = repository;

  final AtkRepository _repository;

  final RxList<AtkItem> items = <AtkItem>[].obs;
  final RxList<AtkLocation> locations = <AtkLocation>[].obs;
  final RxnInt itemId = RxnInt();
  final RxnInt locationId = RxnInt();

  /// The quantity as typed. Read through [quantity].
  final TextEditingController quantityC = TextEditingController(text: '1');

  final RxBool isLoading = true.obs;
  final Rxn<ApiException> loadError = Rxn<ApiException>();
  final RxBool isSubmitting = false.obs;
  final RxnString error = RxnString();

  String? _intentKey;
  String? _intentFingerprint;

  @override
  void onInit() {
    super.onInit();
    loadOptions();
  }

  @override
  void onClose() {
    quantityC.dispose();
    super.onClose();
  }

  /// The items and pickup locations, both or neither: a form with one empty
  /// dropdown is not a form anyone can send.
  Future<void> loadOptions() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      // Both asked at once; the first refusal is the one reported.
      final loaded = await Future.wait<List<Object>>([
        _repository.items(),
        _repository.locations(),
      ]);
      items.assignAll(loaded[0].cast<AtkItem>());
      locations.assignAll(loaded[1].cast<AtkLocation>());
      if (!items.any((item) => item.id == itemId.value)) itemId.value = null;
      if (!locations.any((place) => place.id == locationId.value)) {
        locationId.value = locations.length == 1 ? locations.first.id : null;
      }
    } on ApiException catch (e) {
      loadError.value = e;
    } finally {
      isLoading.value = false;
    }
  }

  /// The typed quantity, or null when it is not a whole number.
  int? get quantity => int.tryParse(quantityC.text.trim());

  AtkItem? get selectedItem =>
      items.firstWhereOrNull((item) => item.id == itemId.value);

  void increment() => _setQuantity((quantity ?? 0) + 1);

  void decrement() {
    final current = quantity ?? 1;
    _setQuantity(current > 1 ? current - 1 : 1);
  }

  void _setQuantity(int value) {
    final text = '$value';
    quantityC.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String? validate() {
    if (itemId.value == null) return 'Pilih barang ATK yang diminta.';
    if (locationId.value == null) return 'Pilih lokasi pengambilan.';
    final qty = quantity;
    if (qty == null || qty < 1) return 'Jumlah minimal 1.';
    return null;
  }

  /// The request number when the server accepted it, or null.
  Future<String?> submit() async {
    if (isSubmitting.value) return null;

    final problem = validate();
    if (problem != null) {
      error.value = problem;
      return null;
    }

    error.value = null;
    isSubmitting.value = true;

    final fingerprint = '${itemId.value}|${locationId.value}|$quantity';
    if (_intentFingerprint != fingerprint) {
      _intentKey = IdempotencyKey.mint();
      _intentFingerprint = fingerprint;
    }

    try {
      final filed = await _repository.createRequest(
        itemId: itemId.value!,
        locationId: locationId.value!,
        quantity: quantity!,
        idempotencyKey: _intentKey!,
      );
      _forgetIntent();
      return filed.number;
    } on ApiException catch (e) {
      if (_isUncertain(e)) {
        // The request may have been filed. Keep the key: sending again is
        // answered with the first reply, never a second request.
        error.value = e.code == 'idempotency_in_progress'
            ? 'Permintaan yang sama masih diproses. Coba lagi sebentar.'
            : 'Permintaan belum pasti terkirim (${e.message}). Kirim ulang — '
                  'sistem tidak akan mencatatnya dua kali.';
      } else {
        error.value = e.firstFieldError ?? e.message;
        _forgetIntent();
      }
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  static bool _isUncertain(ApiException e) =>
      e.isTransportFailure ||
      (e.status ?? 0) >= 500 ||
      e.status == 429 ||
      e.code == 'idempotency_in_progress';

  void _forgetIntent() {
    _intentKey = null;
    _intentFingerprint = null;
  }
}
