import '../../../../core/utils/json_parsers.dart';

/// One calendar month of attendance, counted by the server.
///
/// ## Why the server counts it
///
/// The history list is paginated ten rows at a time, and the month header above
/// it names a month. Counting the loaded rows to fill that header made the
/// screen say "September 2026 · 10 hari tercatat" for a month holding
/// twenty-two — a heading that names a period and a number that describes a
/// page. It was wrong quietly, which is the worst way for an attendance figure
/// to be wrong.
///
/// So `GET /attendances` now answers `summary.months[]` for the whole window it
/// was asked about, and these are those buckets. Everything here describes the
/// entire month inside the requested range, never the page in hand.
class AttendanceMonthTotals {
  const AttendanceMonthTotals({
    required this.month,
    required this.recordedDays,
    required this.lateDays,
    this.averageClockIn,
  });

  /// First day of the month these figures are about.
  final DateTime month;

  /// Days with an attendance row. Days, not rows — one row per person per day
  /// is a database constraint, and counting days says which of the two this
  /// means if that ever stops being true.
  final int recordedDays;

  /// Days whose clock-in the server marked `late`.
  final int lateDays;

  /// `HH:MM`, or null when arrivals were too scattered for a mean to describe
  /// them. Null is an answer here, not a missing value — see
  /// `AttendanceMonthlyTotals::averageClockIn()` on the server, which owns the
  /// definition.
  final String? averageClockIn;

  /// Parse one bucket, or null if it is not one.
  ///
  /// Returns null rather than throwing: this whole block is optional — a
  /// deployment that predates it sends no `summary` at all — and one unreadable
  /// bucket must not cost the list it decorates.
  static AttendanceMonthTotals? tryParse(Object? value) {
    if (value is! Map) return null;

    final json = asObject(value);
    final raw = asString(json['month']);
    if (raw == null) return null;

    final parts = raw.split('-');
    if (parts.length < 2) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;

    return AttendanceMonthTotals(
      month: DateTime(year, month),
      recordedDays: asInt(json['recorded_days']) ?? 0,
      lateDays: asInt(json['late_days']) ?? 0,
      averageClockIn: asString(json['average_clock_in']),
    );
  }

  /// Every bucket in a `summary` block, or null when the server sent none.
  ///
  /// The distinction matters: an empty list means "this window has no
  /// attendance", and null means "this deployment does not answer the
  /// question" — and only one of those is a reason for the screen to stay
  /// quiet about figures it cannot support.
  static List<AttendanceMonthTotals>? tryParseAll(Object? body) {
    if (body is! Map) return null;

    final summary = body['summary'];
    if (summary is! Map) return null;

    final months = summary['months'];
    if (months is! List) return null;

    return <AttendanceMonthTotals>[
      for (final entry in months)
        if (tryParse(entry) case final totals?) totals,
    ];
  }
}
