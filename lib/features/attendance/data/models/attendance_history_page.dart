import 'attendance.dart';
import 'attendance_month_totals.dart';

/// One page of attendance history, and — on the first page only — what the
/// whole requested window adds up to.
///
/// The two travel together because they answer the same request. Asking a
/// second endpoint for the totals would be a second round trip on every filter
/// change, and a summary fetched separately is a summary that can disagree with
/// the list beside it.
class AttendanceHistoryPage {
  const AttendanceHistoryPage({required this.rows, this.monthTotals});

  final List<Attendance> rows;

  /// Per-month figures for the entire window, or **null** when the server did
  /// not send them.
  ///
  /// Null on every page after the first — the totals describe the window, not
  /// the page, so repeating them would be the same answer computed again for
  /// nobody — and null on a deployment that predates the field. Both mean the
  /// same thing to a reader: keep whatever you already had.
  final List<AttendanceMonthTotals>? monthTotals;
}
