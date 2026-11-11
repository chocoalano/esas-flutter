import 'package:get/get.dart';

import '../../../../core/network/api_exception.dart';
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
  final RxList<GamsSpaceReservation> spaceReservations = <GamsSpaceReservation>[].obs;
  final RxList<GamsVehicleBooking> vehicleBookings = <GamsVehicleBooking>[].obs;
  final RxList<GamsVisitorPass> visitorPasses = <GamsVisitorPass>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    isLoading.value = true;
    error.value = null;

    try {
      final sr = await _repository.serviceRequests();
      serviceRequests.assignAll(sr);

      final srSpaces = await _repository.spaceReservations();
      spaceReservations.assignAll(srSpaces);

      final vb = await _repository.vehicleBookings();
      vehicleBookings.assignAll(vb);

      final vp = await _repository.visits();
      visitorPasses.assignAll(vp);
    } on ApiException catch (e) {
      error.value = e;
    } catch (e) {
      error.value = ApiException(e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

