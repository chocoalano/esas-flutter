import 'package:intl/intl.dart';

import '../tenancy/workspace_clock.dart';

/// Indonesian date formatting, in one place, on the workspace's clock.
///
/// ## Two kinds of value, and only one of them has a zone
///
/// A **date** — a birthday, a sign-on date, the day an attendance row belongs
/// to — arrives as `2026-09-02` and means the same calendar day everywhere.
/// Formatting it needs no zone, and giving it one would be how a birthday moves
/// a day.
///
/// A **timestamp** — when a notification arrived, when an activity was logged —
/// arrives as `2026-09-02T09:00:00+07:00` and names an instant. Rendering one
/// requires choosing a zone, and this app used to choose none: `DateTime.parse`
/// converts an offset-bearing string to UTC, and `DateFormat.format` then draws
/// the UTC fields. Nine in the morning in Jakarta was shown as **02:00**.
///
/// `toLocal()` is the wrong repair. It renders in the *handset's* zone, which is
/// a different wrong answer the moment the phone is not in the office — a
/// supervisor in Makassar, anybody travelling, anybody whose clock is set by
/// hand. Times belong to the workspace, so [WorkspaceClock] is what they are
/// drawn in.
///
/// Both functions return their input unchanged when it will not parse. That is
/// deliberate and was the behaviour of `utils/helper.dart`: a list row showing a
/// raw timestamp is worse than one showing a formatted date, but far better than
/// a screen that throws while building.
class DateFormatter {
  const DateFormatter._();

  /// `'2025-07-09'` → `'09 Juli 2025'`.
  static String dayMonthYear(String dateString) =>
      _format(dateString, 'dd MMMM yyyy');

  /// `'2025-07-09'` → `'Rabu, 09 Juli 2025'`.
  static String fullDate(String dateString) =>
      _format(dateString, 'EEEE, dd MMMM yyyy');

  /// An instant, drawn on the workspace's clock.
  ///
  /// This is what every timestamp on every screen goes through. Pass the
  /// `DateTime` a model parsed — the true instant — and it is converted before
  /// it is formatted, rather than after somebody notices the hours are wrong.
  static String timestamp(DateTime? instant, String pattern, {String? locale}) {
    if (instant == null) {
      return '-';
    }

    return DateFormat(
      pattern,
      locale ?? 'id',
    ).format(WorkspaceClock.current.wallClock(instant));
  }

  /// Now, on the workspace's clock, formatted.
  ///
  /// The greeting on the home screen and the date under it both used the
  /// handset's clock, so an employee whose phone had wandered a zone was
  /// greeted for the wrong part of the day and shown the wrong date — while the
  /// attendance beneath it was recorded against the office's.
  static String nowFormatted(String pattern, {String? locale}) =>
      DateFormat(pattern, locale ?? 'id').format(WorkspaceClock.current.now());

  /// Sapaan untuk bagian hari yang sedang berlaku di KANTOR.
  ///
  /// Ada di sini dan bukan di dalam widget yang memakainya karena ia adalah
  /// pertanyaan tentang jam, bukan tentang tampilan — dan karena batasnya harus
  /// bisa diuji tanpa membangun satu widget pun. Seseorang yang ponselnya ikut
  /// bepergian pernah disapa untuk bagian hari yang salah; jamnya diambil dari
  /// [WorkspaceClock], sama seperti setiap jam lain di aplikasi ini.
  static String greeting() =>
      greetingForHour(WorkspaceClock.current.now().hour);

  /// Sapaan untuk sebuah jam 0–23. Batasnya adalah konvensi yang sudah berjalan
  /// di produk ini: pagi sampai 10:59, siang sampai 14:59, sore sampai 18:59.
  ///
  /// Jam di luar 0–23 tidak mungkin datang dari sebuah `DateTime`, tetapi
  /// fungsinya publik dan karena itu tetap menjawab sesuatu yang masuk akal
  /// alih-alih melempar di layar pertama aplikasi.
  static String greetingForHour(int hour) {
    if (hour < 0 || hour > 23) return 'Halo';
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 19) return 'Selamat sore';

    return 'Selamat malam';
  }

  static String _format(String dateString, String pattern) {
    // Built outside the `try` on purpose. The old helper wrapped both steps in
    // a bare `catch (e)`, so an uninitialised `id` locale — a boot-order bug —
    // rendered every date on every screen as a raw ISO string with nothing
    // said. Only the parse is forgiving.
    final formatter = DateFormat(pattern, 'id');

    try {
      final parsed = DateTime.parse(dateString);

      // A bare `2026-09-02` parses as local midnight and carries no zone, so it
      // is formatted as it is. Anything that named an instant is moved onto the
      // workspace's clock first.
      return formatter.format(
        parsed.isUtc ? WorkspaceClock.current.wallClock(parsed) : parsed,
      );
    } on FormatException {
      return dateString;
    }
  }
}
