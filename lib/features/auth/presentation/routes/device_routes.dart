/// Where the attendance-device screens live in the route table (ADR-D).
///
/// A leaf, like `AuthRoutes`: it imports nothing, so the attendance gate can
/// name the destination without pulling in the enrolment view.
class DeviceRoutes {
  const DeviceRoutes._();

  /// Enter the HR activation code and enrol this phone for attendance.
  static const enrollment = '/device/enrollment';
}
