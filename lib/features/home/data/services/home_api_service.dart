import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';

/// Everything the dashboard and its two sub-screens ask for.
///
/// Six endpoint strings used to live across `HomeController`,
/// `ActivityController`, `AnnouncementController` and
/// `AnnouncementDetailController` (MED-01).
///
/// Two of them changed shape rather than just address. The clock-in context no
/// longer takes an employee id — the token names the person, and an endpoint
/// that accepted an id would be one an employee could point at a colleague —
/// and "active announcements" is a filter on the list rather than a second
/// endpoint.
class HomeApiService {
  const HomeApiService(this._client);

  final ApiClient _client;

  /// Everything the clock-in screen needs to draw itself: shift, today's
  /// attendance, whether the next tap is an arrival or a departure, the
  /// geofence, and whether this account may clock at all.
  ///
  /// Takes no employee. The old backend's `/auth/current-attendance/{id}` asked
  /// the phone who was standing in front of it, which is a question no
  /// attendance system should accept an answer to.
  Future<Map<String, dynamic>> attendanceContext() =>
      _client.getObject(ApiRoutes.attendanceContext);

  /// The roster, with public holidays folded in.
  ///
  /// A roster row on a public holiday and one on an ordinary Tuesday look
  /// identical, and only one of them means somebody is expected — so the server
  /// marks each day rather than leaving the app to work it out.
  Future<Map<String, dynamic>> schedule({String? from, String? to}) =>
      _client.getObject(
        ApiRoutes.schedule,
        query: {if (from != null) 'from': from, if (to != null) 'to': to},
      );

  /// The same window, counted: worked days and late arrivals.
  ///
  /// The one endpoint on this screen that is also read elsewhere — the profile
  /// header asks it too. Both go through their own repository rather than
  /// sharing one, because they ask different questions of the same answer: the
  /// profile wants a standing, the dashboard wants this month.
  Future<Map<String, dynamic>> attendanceSummary({int? year, int? month}) =>
      _client.getObject(
        ApiRoutes.attendanceSummary,
        query: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );

  /// How much leave is left, per type that keeps a balance.
  Future<Map<String, dynamic>> leaveBalance({int? year}) => _client.getObject(
    ApiRoutes.leaveBalance,
    query: {if (year != null) 'year': year},
  );

  /// Beberapa pengajuan terakhir milik karyawan yang sedang masuk.
  ///
  /// Endpoint yang sama dengan layar Pengajuan, dan **tidak menerima employee
  /// id**: siapa pemilik barisnya adalah keputusan server yang dibuat dari
  /// token, persis seperti riwayat absensi. Sebuah filter yang dipilih client
  /// adalah filter yang bisa diubah client.
  ///
  /// `per_page` kecil dan disengaja: Beranda menampilkan tiga baris, dan
  /// mengambil dua puluh untuk membuang tujuh belas adalah beban jaringan di
  /// layar yang dibuka paling sering.
  Future<Map<String, dynamic>> recentPermits({int perPage = 3}) => _client
      .getObject(ApiRoutes.permits, query: {'page': 1, 'per_page': perPage});

  /// Published notices only. A filter on [announcements], not a second
  /// endpoint: a list and the same list narrowed are not two resources.
  Future<Map<String, dynamic>> activeAnnouncements({int perPage = 20}) =>
      _client.getObject(
        ApiRoutes.announcements,
        query: {'active': 1, 'per_page': perPage},
      );

  /// What this account has been doing — the security screen.
  Future<Map<String, dynamic>> activity({int page = 1, int perPage = 20}) =>
      _client.getObject(
        ApiRoutes.activity,
        query: {'page': page, 'per_page': perPage},
      );

  /// A page of notices.
  ///
  /// Answers a Laravel paginator — `{data, current_page, per_page, total}` —
  /// rather than a bare array, and takes `per_page`. The old backend's `limit`
  /// is not a synonym for it and is ignored.
  Future<Map<String, dynamic>> announcements({
    required int page,
    required int perPage,
  }) {
    return _client.getObject(
      ApiRoutes.announcements,
      query: {'page': page, 'per_page': perPage},
    );
  }

  Future<Map<String, dynamic>> announcement(Object id) =>
      _client.getObject(ApiRoutes.announcement(id));
}
