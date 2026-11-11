import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/models/gams_service_request.dart';
import '../../data/models/gams_space_reservation.dart';
import '../../data/models/gams_vehicle_booking.dart';
import '../../data/repositories/gams_repository.dart';

/// What the form files.
enum GamsCreateKind {
  serviceRequest('Ajukan permintaan layanan', 'Layanan'),
  spaceReservation('Pesan ruang', 'Ruang'),
  vehicleBooking('Pinjam kendaraan', 'Kendaraan'),
  visit('Daftarkan tamu', 'Gedung');

  const GamsCreateKind(this.title, this.optionLabel);

  final String title;
  final String optionLabel;

  bool get hasPeriod => this == spaceReservation || this == vehicleBooking;
}

/// One form for the four GAMS requests the dashboard and the home screen
/// offer (GAMS-01). Every one of those buttons used to open the dashboard
/// itself: the repository could file all four, and nothing on screen could.
///
/// The rules mirror the server's validation — required choices, a subject or
/// purpose, an end after the start — so a refusal is explained before the
/// request rather than after it.
class GamsCreateController extends GetxController {
  GamsCreateController({required GamsRepository repository, required this.kind})
    : _repository = repository;

  final GamsRepository _repository;
  final GamsCreateKind kind;

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxnString error = RxnString();

  final RxList<GamsServiceDefinition> definitions =
      <GamsServiceDefinition>[].obs;
  final RxList<GamsFacility> facilities = <GamsFacility>[].obs;
  final RxList<GamsSpace> spaces = <GamsSpace>[].obs;
  final RxList<GamsVehicle> vehicles = <GamsVehicle>[].obs;

  /// The service, room or vehicle chosen.
  final RxnInt optionId = RxnInt();

  /// The building: optional on a service request, required for a visitor.
  final RxnInt facilityId = RxnInt();

  final RxString priority = 'medium'.obs;
  final Rxn<DateTime> startAt = Rxn<DateTime>();
  final Rxn<DateTime> endAt = Rxn<DateTime>();

  /// Subject for a service request; purpose for a vehicle or a visitor.
  final TextEditingController subjectC = TextEditingController();
  final TextEditingController descriptionC = TextEditingController();
  final TextEditingController visitorNameC = TextEditingController();
  final TextEditingController visitorPhoneC = TextEditingController();
  final TextEditingController visitorCompanyC = TextEditingController();

  String? _intentKey;
  String? _intentFingerprint;

  @override
  void onInit() {
    super.onInit();
    loadOptions();
  }

  @override
  void onClose() {
    for (final c in [
      subjectC,
      descriptionC,
      visitorNameC,
      visitorPhoneC,
      visitorCompanyC,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> loadOptions() async {
    isLoading.value = true;
    error.value = null;

    try {
      switch (kind) {
        case GamsCreateKind.serviceRequest:
        case GamsCreateKind.visit:
          final catalog = await _repository.definitions();
          definitions.assignAll(catalog.definitions);
          facilities.assignAll(catalog.facilities);
        case GamsCreateKind.spaceReservation:
          spaces.assignAll(await _repository.spaces());
        case GamsCreateKind.vehicleBooking:
          vehicles.assignAll(await _repository.vehicles());
      }
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Why this cannot be sent yet, or null.
  String? validate() {
    final subject = subjectC.text.trim();

    switch (kind) {
      case GamsCreateKind.serviceRequest:
        if (optionId.value == null) return 'Pilih layanan yang diminta.';
        if (subject.isEmpty) return 'Isi judul permintaan.';
      case GamsCreateKind.spaceReservation:
        if (optionId.value == null) return 'Pilih ruang yang dipesan.';
      case GamsCreateKind.vehicleBooking:
        if (optionId.value == null) return 'Pilih kendaraan.';
        if (subject.isEmpty) return 'Isi keperluan peminjaman.';
      case GamsCreateKind.visit:
        if (facilityId.value == null) return 'Pilih gedung yang dikunjungi.';
        if (visitorNameC.text.trim().isEmpty) return 'Isi nama tamu.';
        if (subject.isEmpty) return 'Isi keperluan kunjungan.';
    }

    if (kind.hasPeriod) {
      final start = startAt.value;
      final end = endAt.value;
      if (start == null || end == null) return 'Isi waktu mulai dan selesai.';
      if (!end.isAfter(start)) {
        return 'Waktu selesai harus setelah waktu mulai.';
      }
    }

    return null;
  }

  /// Send the request. True when the server accepted it.
  ///
  /// One request per intent: a second tap while the first is on its way does
  /// nothing, and a retry of the same content reuses the same key.
  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    final problem = validate();
    if (problem != null) {
      error.value = problem;
      return false;
    }

    error.value = null;
    isSubmitting.value = true;

    final fingerprint = _fingerprint();
    if (_intentFingerprint != fingerprint) {
      _intentKey = IdempotencyKey.mint();
      _intentFingerprint = fingerprint;
    }

    try {
      await _send(_intentKey!);
      _intentKey = null;
      _intentFingerprint = null;
      return true;
    } on ApiException catch (e) {
      error.value = e.firstFieldError ?? e.message;
      if (e.status != null && e.status! < 500 && e.status != 429) {
        _intentKey = null;
        _intentFingerprint = null;
      }
      AppLogger.warning('GAMS ${kind.name} refused: ${e.code ?? e.status}');
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<void> _send(String key) {
    final subject = subjectC.text.trim();
    final description = descriptionC.text.trim();

    return switch (kind) {
      GamsCreateKind.serviceRequest => _repository.createServiceRequest(
        serviceDefinitionId: optionId.value!,
        facilityId: facilityId.value,
        subject: subject,
        description: description.isEmpty ? null : description,
        priority: priority.value,
        idempotencyKey: key,
      ),
      GamsCreateKind.spaceReservation => _repository.createSpaceReservation(
        spaceId: optionId.value!,
        startAt: workspaceInstant(startAt.value!),
        endAt: workspaceInstant(endAt.value!),
        idempotencyKey: key,
      ),
      GamsCreateKind.vehicleBooking => _repository.createVehicleBooking(
        vehicleId: optionId.value!,
        purpose: subject,
        startsAt: workspaceInstant(startAt.value!),
        endsAt: workspaceInstant(endAt.value!),
      ),
      GamsCreateKind.visit => _repository.createVisit(
        facilityId: facilityId.value!,
        visitorName: visitorNameC.text.trim(),
        visitorPhone: _orNull(visitorPhoneC.text),
        visitorCompany: _orNull(visitorCompanyC.text),
        purpose: subject,
      ),
    };
  }

  String _fingerprint() => [
    kind.name,
    optionId.value,
    facilityId.value,
    priority.value,
    startAt.value?.toIso8601String(),
    endAt.value?.toIso8601String(),
    subjectC.text.trim(),
    descriptionC.text.trim(),
    visitorNameC.text.trim(),
    visitorPhoneC.text.trim(),
    visitorCompanyC.text.trim(),
  ].join('|');

  static String? _orNull(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  /// A wall-clock time picked on the workspace's clock, as an instant the
  /// server cannot misread: ISO 8601 with the workspace's offset.
  static String workspaceInstant(DateTime wall) {
    String two(int v) => v.toString().padLeft(2, '0');

    final offset = WorkspaceClock.current.offsetMinutes;
    final sign = offset < 0 ? '-' : '+';
    final abs = offset.abs();

    return '${wall.year.toString().padLeft(4, '0')}-${two(wall.month)}-'
        '${two(wall.day)}T${two(wall.hour)}:${two(wall.minute)}:00'
        '$sign${two(abs ~/ 60)}:${two(abs % 60)}';
  }
}
