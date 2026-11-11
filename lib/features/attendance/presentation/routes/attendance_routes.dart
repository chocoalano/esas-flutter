/// Where the attendance feature's screens live in the route table.
class AttendanceRoutes {
  const AttendanceRoutes._();

  static const attendance = '/attendance';
  static const list = '$attendance$listSegment';
  static const overtime = '/overtime';

  static const listSegment = '/list';
}
