import 'dart:convert';

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

  /// Why the options (services, rooms, vehicles) could not be loaded, kept
  /// apart from a submit error so the form can offer a retry instead of an
  /// empty dropdown (UX-A07).
  final Rxn<ApiException> loadError = Rxn<ApiException>();

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

  /// What the requester typed into the chosen service's own fields
  /// (FUNC-A01), by field key. Cleared when another service is chosen.
  final RxMap<String, Object?> fieldValues = <String, Object?>{}.obs;

  String? _intentKey;
  String? _intentFingerprint;

  @override
  void onInit() {
    super.onInit();
    ever<int?>(optionId, (_) {
      if (kind == GamsCreateKind.serviceRequest) fieldValues.clear();
    });
    loadOptions();
  }

  /// The service chosen on a service request, or null.
  GamsServiceDefinition? get selectedDefinition {
    final id = optionId.value;
    return id == null ? null : definitions.firstWhereOrNull((d) => d.id == id);
  }

  void setField(String key, Object? value) {
    final empty =
        value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty);
    if (empty) {
      fieldValues.remove(key);
    } else {
      fieldValues[key] = value;
    }
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
    loadError.value = null;

    try {
      switch (kind) {
        case GamsCreateKind.serviceRequest:
        case GamsCreateKind.visit:
          final catalog = await _repository.definitions();
          // Only services whose required fields this app can draw: any other
          // would be refused after sending (FUNC-A01).
          definitions.assignAll(
            catalog.definitions.where((d) => d.isRequestable),
          );
          facilities.assignAll(catalog.facilities);
        case GamsCreateKind.spaceReservation:
          spaces.assignAll(await _repository.spaces());
        case GamsCreateKind.vehicleBooking:
          vehicles.assignAll(await _repository.vehicles());
      }
    } on ApiException catch (e) {
      loadError.value = e;
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
        final definition = selectedDefinition;
        if (definition != null) {
          if (definition.requiresFacility && facilityId.value == null) {
            return 'Layanan ini memerlukan lokasi gedung.';
          }
          if (definition.requiresDescription &&
              descriptionC.text.trim().isEmpty) {
            return 'Layanan ini memerlukan keterangan.';
          }
          for (final field in definition.fields) {
            if (field.required && !fieldValues.containsKey(field.key)) {
              return 'Isi "${field.label}".';
            }
          }
        }
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
        fields: fieldPayload(),
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
        // A retry after a lost answer replays the first booking (FUNC-A04)
        // instead of meeting "vehicle already booked" for one's own booking.
        idempotencyKey: key,
      ),
      GamsCreateKind.visit => _repository.createVisit(
        facilityId: facilityId.value!,
        visitorName: visitorNameC.text.trim(),
        visitorPhone: _orNull(visitorPhoneC.text),
        visitorCompany: _orNull(visitorCompanyC.text),
        purpose: subject,
        idempotencyKey: key,
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
    jsonEncode(fieldPayload() ?? const {}),
  ].join('|');

  /// The chosen service's fields as the server reads them: dates as
  /// `yyyy-MM-dd`, date-times on the workspace's clock, only fields the
  /// service declares, and nothing at all when none was filled.
  Map<String, Object?>? fieldPayload() {
    final definition = selectedDefinition;
    if (definition == null || fieldValues.isEmpty) return null;

    final payload = <String, Object?>{};
    for (final field in definition.fields) {
      final value = fieldValues[field.key];
      if (value == null) continue;
      payload[field.key] = switch ((field.type, value)) {
        (GamsFieldType.date, DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}',
        (GamsFieldType.datetime, DateTime d) => workspaceInstant(d),
        _ => value,
      };
    }

    return payload.isEmpty ? null : payload;
  }

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
