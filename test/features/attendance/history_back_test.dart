import 'package:esas/features/attendance/presentation/routes/attendance_routes.dart';
import 'package:esas/features/attendance/presentation/views/attendance_list_view.dart';
import 'package:esas/features/home/presentation/routes/home_routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// ATTP-17. Back from the history always opened the capture screen — which
/// starts the camera and asks for permissions — even when the history had been
/// opened from the home screen.
void main() {
  test('back returns to where the history was opened from', () {
    expect(
      AttendanceListView.backTarget({'back': HomeRoutes.home}),
      HomeRoutes.home,
    );
  });

  test('with no origin, back is the capture screen as before', () {
    expect(AttendanceListView.backTarget(null), AttendanceRoutes.attendance);
  });
}
