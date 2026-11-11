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

  /// Whether attendance is enabled for the employee, independently of the
  /// permission granted to this device's token.
  bool? get attendanceEnabled => asBool(raw['attendance_enabled']);

  /// Whether this session may record attendance.
  ///
  /// Login sends device capability and token abilities outside `user`; the
  /// repository keeps them in [raw]. An older payload without either remains
  /// unknown so it can still ask the attendance endpoint.
  bool? get canRecordAttendance {
    final devicePermission =
        asBool(dig(raw, ['device', 'can_record_attendance'])) ??
        asBool(raw['can_record_attendance']);
    if (devicePermission != null) return devicePermission;

    final abilities = raw['abilities'];
    if (abilities is! List || abilities.any((value) => value is! String)) {
      return null;
    }

    return abilities.contains('attendance') || abilities.contains('*');
  }

  /// Whether the current device matches the employee's registered device.
  /// Missing metadata does not establish that it is unregistered.
  bool? get isRegisteredDevice =>
      asBool(dig(raw, ['device', 'is_registered_device'])) ??
      asBool(raw['is_registered_device']);

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

  /// The active modules entitled for this workspace.
  List<String> get activeModules {
    final modules = asList(raw['active_modules']);
    if (modules.isEmpty) {
      return const ['hrms'];
    }
    return modules.map((e) => '$e').toList();
  }

  bool isModuleActive(String module) =>
      activeModules.contains(module.toLowerCase());

  bool get hasGams => isModuleActive('gams');
  bool get hasItms => isModuleActive('itms');
  bool get hasMtms => isModuleActive('mtms');
  bool get hasHrms => isModuleActive('hrms');

  /// Whether this employee has managerial / approver responsibilities.
  bool get isApprover => asBool(raw['is_approver']) ?? false;

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

  /// The job title, as whichever payload sent it (PROF-02).
  ///
  /// Login and `/auth/me` send `job_position` flat, as a string; `/profile`
  /// sends it on `employee`, also as a name. Only an older backend nested it
  /// as `{name}` — the one shape this used to read, so it read nothing.
  String? get jobPosition {
    for (final candidate in [
      raw['job_position'],
      dig(raw, ['employee', 'job_position']),
      dig(raw, ['employee', 'job_position', 'name']),
    ]) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    return null;
  }

  DateTime? get signDate => asDate(dig(raw, ['employee', 'sign_date']));

  Map<String, dynamic> toJson() => raw;

  /// What of the session may be written to the device (PROF-01).
  ///
  /// The cached user lives in GetStorage: a plaintext JSON file in the
  /// documents directory, included in device backups. It used to receive the
  /// whole `/profile` reply — basic salary, bank account, NIK, family, date of
  /// birth — because the profile screens merged it in to keep the dashboard in
  /// step. Only what the getters above read is allowed through; everything
  /// else stays in memory with the screen that fetched it.
  ///
  /// An allow-list rather than a deny-list: a field the server adds tomorrow is
  /// kept off the disk until somebody decides it belongs there.
  Map<String, dynamic> toSessionJson() => sessionSafe(raw);

  static const _sessionKeys = <String>{
    'id',
    'tenant_id',
    'name',
    'nip',
    'email',
    'avatar',
    'status',
    'company_id',
    'departement',
    'job_position',
    'attendance_enabled',
    'face_enrolled',
    'can_record_attendance',
    'is_registered_device',
    'device',
    'abilities',
    'active_modules',
    'is_approver',
    'timezone',
    'server_time',
    'unread_notification_count',
    'notification_count',
  };

  static const _companyKeys = <String>{
    'id',
    'name',
    'latitude',
    'longitude',
    'radius',
  };

  static const _employeeKeys = <String>{
    'user_id',
    'departement_id',
    'departement',
    'job_position',
    'job_level',
    'join_date',
    'sign_date',
  };

  /// [raw] reduced to what [toSessionJson] allows.
  static Map<String, dynamic> sessionSafe(Map<dynamic, dynamic> raw) {
    final safe = <String, dynamic>{};

    for (final entry in raw.entries) {
      final key = '${entry.key}';
      if (_sessionKeys.contains(key)) safe[key] = entry.value;
    }

    // Login sends `company` as a name, `/profile` as an object.
    final company = raw['company'];
    if (company is Map) {
      safe['company'] = _pick(company, _companyKeys);
    } else if (company != null) {
      safe['company'] = company;
    }

    final employee = raw['employee'];
    if (employee is Map) {
      safe['employee'] = _pick(employee, _employeeKeys);
    }

    return safe;
  }

  static Map<String, dynamic> _pick(
    Map<dynamic, dynamic> from,
    Set<String> keys,
  ) => {
    for (final entry in from.entries)
      if (keys.contains('${entry.key}')) '${entry.key}': entry.value,
  };

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
/// Only the server's 401 ends a session. Not reaching the server says nothing
/// about the credential, so it is kept (CORE-04).
enum SessionState {
  /// No credential stored. Show login.
  absent,

  /// The server confirmed the token. Show the app.
  authenticated,

  /// The server rejected the token. Clear it and show login.
  expired,

  /// The server could not be reached, and there is a cached user to show.
  /// Keep the credential and open the app on what it already knows; the next
  /// request that does reach the server settles the question.
  unverified,

  /// The server could not be reached and nothing is cached to show. Keep the
  /// credential and explain that a connection is needed.
  connectionLost,

  /// Verification failed with an HTTP or data error. Keep the credential.
  offline,
}
