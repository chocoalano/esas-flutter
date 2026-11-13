import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../data/models/gams_service_request.dart';
import '../../data/models/gams_space_reservation.dart';
import '../../data/models/gams_vehicle_booking.dart';
import '../../data/models/gams_visitor_pass.dart';
import '../../data/repositories/gams_repository.dart';

class GamsDashboardController extends GetxController {
  GamsDashboardController({required GamsRepository repository})
    : _repository = repository;

  final GamsRepository _repository;

  final isLoading = true.obs;
  final Rxn<ApiException> error = Rxn<ApiException>();

  final RxList<GamsServiceRequest> serviceRequests = <GamsServiceRequest>[].obs;
  final RxList<GamsSpaceReservation> spaceReservations =
      <GamsSpaceReservation>[].obs;
  final RxList<GamsVehicleBooking> vehicleBookings = <GamsVehicleBooking>[].obs;
  final RxList<GamsVisitorPass> visitorPasses = <GamsVisitorPass>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  /// The rows one page of each list holds — what the API is asked for.
  static const int pageSize = 20;

  /// Requests still waiting on somebody (GAMS-03). "Aktif" used to count the
  /// resolved and closed ones too.
  int get activeServiceRequests =>
      serviceRequests.where((request) => !request.isClosed).length;

  /// A count drawn from the first page only (GAMS-03).
  ///
  /// The dashboard reads one page of each list. When that page came back full
  /// there may be more behind it, and "20" would be a total nobody counted —
  /// so it says "20+".
  static String countLabel(int count, {required int loaded}) =>
      loaded >= pageSize ? '$count+' : '$count';

  /// Why a section could not be loaded, by section (GAMS-02).
  final RxMap<String, ApiException> sectionErrors =
      <String, ApiException>{}.obs;

  /// Load the four sections side by side, each failing on its own (GAMS-02).
  ///
  /// They used to run one after another in one `try`: a 403 on the visitor
  /// book — somebody without access to it — hid the three that had loaded,
  /// and trying again failed the same way. The screen-wide [error] is kept for
  /// the case where nothing at all could be loaded.
  final Map<String, String> _cancelKeys = {};

  /// Withdraws one of the requester's bookings through the domain (D-06,
  /// F-21). Null when it went through, otherwise the message to show; a lost
  /// answer keeps the Idempotency-Key so a retry cannot cancel twice.
  Future<String?> cancelBooking({
    required bool vehicle,
    required int id,
    required String reason,
  }) async {
    final intent = '${vehicle ? 'v' : 's'}:$id:$reason';
    final key = _cancelKeys[intent] ??= IdempotencyKey.mint();
    try {
      final why = reason.isEmpty ? null : reason;
      if (vehicle) {
        await _repository.cancelVehicleBooking(
          id,
          reason: why,
          idempotencyKey: key,
        );
      } else {
        await _repository.cancelSpaceReservation(
          id,
          reason: why,
          idempotencyKey: key,
        );
      }
      _cancelKeys.remove(intent);
      await loadDashboard();
      return null;
    } on ApiException catch (e) {
      if (e.status != null && e.status! < 500 && e.status != 429) {
        _cancelKeys.remove(intent);
        await loadDashboard();
      }
      return e.message;
    }
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = null;
    sectionErrors.clear();

    Future<void> section<T>(
      String key,
      Future<List<T>> Function() load,
      RxList<T> into,
    ) async {
      try {
        into.assignAll(await load());
      } on ApiException catch (e) {
        sectionErrors[key] = e;
      } catch (e) {
        sectionErrors[key] = ApiException(e.toString());
      }
    }

    try {
      await Future.wait([
        section(
          'serviceRequests',
          _repository.serviceRequests,
          serviceRequests,
        ),
        section(
          'spaceReservations',
          _repository.spaceReservations,
          spaceReservations,
        ),
        section(
          'vehicleBookings',
          _repository.vehicleBookings,
          vehicleBookings,
        ),
        section('visits', _repository.visits, visitorPasses),
      ]);

      if (sectionErrors.length == 4) {
        error.value = sectionErrors.values.first;
      }
    } finally {
      isLoading.value = false;
    }
  }
}
