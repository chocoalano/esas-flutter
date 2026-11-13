class GamsRoutes {
  const GamsRoutes._();

  static const gams = '/gams';
  static const serviceRequests = '$gams/service-requests';
  static const spaceReservations = '$gams/space-reservations';
  static const vehicleBookings = '$gams/vehicle-bookings';
  static const visitorPasses = '$gams/visitor-passes';

  /// Every service request of the requester's (FUNC-D05).
  static const requests = '$gams/requests';

  /// One service request; the argument is its id.
  static const requestDetail = '$gams/requests/detail';
}
