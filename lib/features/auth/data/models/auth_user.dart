import '../../../../core/tenancy/workspace_clock.dart';
import '../../../../core/utils/json_parsers.dart';

/// The signed-in employee.
///
/// Keeps [raw] alongside the typed accessors, and that is deliberate rather than
/// lazy. Unmigrated controllers still read the whole user object out of
/// `GetStorage` under `auth_user_json` and reach into it by key —
/// `user['company']['latitude']`, `user['employee']['departement_id']`. Dropping
/// the untyped map here would break every one of them at once.
///
/// Phases 4–5 replace those reads feature by feature. When the last one is gone,
/// [raw] goes with it.
class AuthUser {
  const AuthUser({required this.raw});

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(raw: Map<String, dynamic>.unmodifiable(json));

  /// The server's user object, verbatim.
  final Map<String, dynamic> raw;

  int? get id => asInt(raw['id']);

  String? get name => asString(raw['name']);

  String? get nip => asString(raw['nip']);

  String? get avatar => asString(raw['avatar']);

  String? get status => asString(raw['status']);

  /// Berapa notifikasi yang belum dibaca, menurut server.
  ///
  /// `null` berarti server pada instalasi ini TIDAK mengirimkannya, dan itu
  /// bukan nol: lencana yang menggambar "0" untuk sesuatu yang tidak diketahui
  /// sama menyesatkannya dengan lencana yang menggambar angka yang salah.
  ///
  /// Kontraknya sengaja dinamai `unread_notification_count` dan bukan
  /// `notification_count` — yang digambar lencana adalah yang BELUM DIBACA, dan
  /// sebuah nama yang tidak menyebutkannya akan diisi backend dengan jumlah
  /// seluruh notifikasi cepat atau lambat. Ejaan yang lebih pendek tetap
  /// diterima sebagai cadangan supaya backend yang sudah terlanjur mengirimnya
  /// tidak menjadi lencana yang hilang.
  int? get unreadNotificationCount =>
      asInt(raw['unread_notification_count']) ??
      asInt(raw['notification_count']);

  /// Which of Indonesia's three clocks this workspace runs on.
  ///
  /// Carried with the session because it is needed before any screen draws a
  /// time, and because it is a property of the workspace rather than of the
  /// handset. Falls back to WIB when a server predates the field, which is the
  /// value that server was itself using.
  WorkspaceClock get clock => WorkspaceClock.fromJson(raw['timezone']);

  /// Company id, from either the flat column or the nested object.
  int? get companyId =>
      asInt(raw['company_id']) ?? asInt(dig(raw, ['company', 'id']));

  /// The geofence centre for attendance.
  ///
  /// Null on the `tenancy-app` payload, which flattens `company` to a name —
  /// that is gap G-1 in `06-api-migration-map.md`, and it blocks Phase 4.
  double? get companyLatitude => asDouble(dig(raw, ['company', 'latitude']));

  double? get companyLongitude => asDouble(dig(raw, ['company', 'longitude']));

  double? get companyRadius => asDouble(dig(raw, ['company', 'radius']));

  int? get departementId => asInt(dig(raw, ['employee', 'departement_id']));

  /// The employee's own user id as the HRIS records it.
  ///
  /// Not always the same as [id]: attendance posts `employee.user_id`, and the
  /// two have been observed to differ.
  int? get employeeUserId => asInt(dig(raw, ['employee', 'user_id']));

  String? get jobPosition =>
      asString(dig(raw, ['employee', 'job_position', 'name']));

  DateTime? get signDate => asDate(dig(raw, ['employee', 'sign_date']));

  Map<String, dynamic> toJson() => raw;

  AuthUser copyWith({String? name, String? avatar}) {
    final next = Map<String, dynamic>.from(raw);

    if (name != null) {
      next['name'] = name;
    }

    if (avatar != null) {
      next['avatar'] = avatar;
    }

    return AuthUser(raw: Map<String, dynamic>.unmodifiable(next));
  }
}

/// What a session restore concluded.
///
/// Three outcomes, not two. The old `SplashController` had only "valid" and
/// "everything else", and cleared the session for everything else — so opening
/// the app with no signal signed the employee out (HIGH-02).
enum SessionState {
  /// No credential stored. Show login.
  absent,

  /// The server confirmed the token. Show the app.
  authenticated,

  /// The server rejected the token. Clear it and show login.
  expired,

  /// The server could not be reached. **Keep the credential** and let the
  /// person retry; this is not evidence of anything about the session.
  offline,
}
