import 'dart:io';

import '../../../../core/utils/json_parsers.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../features/auth/data/models/auth_user.dart';
import '../../../../features/auth/data/repositories/session_repository.dart';
import '../models/user.dart';
import '../services/profile_api_service.dart';

/// The employee's own record.
///
/// Five profile sub-screens — personal, worked, family, education, experience —
/// each fetched `/general-module/auth` independently on open, so walking the
/// tabs made five identical network calls for one user object. They share one
/// cached read here.
class ProfileRepository {
  ProfileRepository({
    required ProfileApiService api,
    required SessionRepository session,
  }) : _api = api,
       _session = session;

  final ProfileApiService _api;
  final SessionRepository _session;

  User? _cached;
  Future<User>? _inFlight;

  /// The full employee record.
  ///
  /// [refresh] forces a re-fetch — needed where a tab must show an edit made on
  /// another. Concurrent callers share one request rather than racing, which is
  /// what four tabs opening at once would otherwise do.
  Future<User> currentUser({bool refresh = false}) {
    final cached = _cached;

    if (!refresh && cached != null) {
      return Future.value(cached);
    }

    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<User> _fetch() async {
    // `/profile`, not `/auth/me`. The two answer different questions and only
    // one of them is the employee record: signing in says *who you are*, and
    // this app used to keep that payload and read domain data out of it — so a
    // department HR changed was still the old one until somebody signed out.
    //
    // It is also what the crash was. `/auth/me` flattens `company` to its name,
    // and feeding a string to `Company.fromJson` is a type error before the
    // screen draws anything.
    final token = _session.token;
    final body = await _api.profile();
    if (token != _session.token) {
      throw const ApiException('Sesi berubah. Muat ulang profil.');
    }
    final user = User.fromJson(_asUserJson(body));

    _cached = user;

    // Keep the session's copy in step, so the dashboard and attendance read the
    // same record the profile screens just loaded.
    final identity = asObject(body['user']);

    if (identity.isNotEmpty) {
      await _session.updateUser(
        AuthUser.fromJson({...?_session.user?.raw, ...identity, ...body}),
      );
    }

    return user;
  }

  /// Reshape the `/profile` contract into what [User] declares.
  ///
  /// The two disagree, and deliberately: the contract is domain-shaped —
  /// `user`, `company`, `employee` and the collections as siblings, with the
  /// department, position and level as **names** — while this model was
  /// generated against the retired backend's row-shaped payload. Bending the
  /// contract to fit a legacy model would be the wrong way round, and rewriting
  /// every profile view is a bigger change than this feature needs.
  ///
  /// So the translation lives here, which is what a repository is for. The
  /// views do not know it happened.
  Map<String, dynamic> _asUserJson(Map<String, dynamic> body) {
    final company = asObject(body['company']);
    final employee = asObject(body['employee']);
    final addresses = asList(body['addresses']);

    return {
      ...asObject(body['user']),
      // `company_id` is not on the contract's user block; the company object
      // carries its own id, and this model wants both.
      'company_id': company['id'],
      'company': company.isEmpty ? null : company,
      'details': body['detail'],
      // The schema keeps one address per person. The contract sends a
      // collection so it stays a collection the day somebody is allowed two;
      // this model wants the one.
      'address': addresses.isEmpty ? null : addresses.first,
      'salaries': body['salary'],
      'families': body['families'],
      'formal_educations': body['educations'],
      'informal_educations': body['informal_educations'],
      'work_experiences': body['experiences'],
      'employee': employee.isEmpty
          ? null
          : {
              ...employee,
              // Names back into the object shape the model declares. The id is
              // carried where the contract gives one, so a screen that needs
              // more than a label has somewhere to go.
              'departement': _named(
                employee['departement_id'],
                employee['departement'],
              ),
              'job_position': _named(null, employee['job_position']),
              'job_level': _named(null, employee['job_level']),
            },
    };
  }

  /// A `{id, name}` object from a name, or null when there is no name.
  Map<String, dynamic>? _named(Object? id, Object? name) {
    final label = asString(name);

    return label == null ? null : {'id': id, 'name': label};
  }

  /// Attendance counters for the profile header.
  Future<({double points, int late, int attendance, int onTime})>
  attendanceSummary() async {
    final body = await _api.attendanceSummary();
    final summary = asObject(body['summary']);

    // The keys moved from the retired backend's Indonesian ones —
    // `total_absensi`, `total_terlambat`, `persen_point` — to the figures
    // payroll itself counts. Reading the old names returned nothing and the
    // profile header showed four zeroes for an employee who had worked all
    // month.
    final worked = asDouble(summary['worked_days'])?.round() ?? 0;
    final late = asInt(summary['late_count']) ?? 0;

    // On-time days and the percentage are derived here rather than asked for:
    // the server counts days worked and days late, and a third figure that is
    // simply their difference is a third thing that can disagree.
    final onTime = worked - late < 0 ? 0 : worked - late;

    return (
      points: worked == 0 ? 0.0 : (onTime / worked) * 100,
      late: late,
      attendance: worked,
      onTime: onTime,
    );
  }

  /// Upload a new avatar and return its new path.
  Future<String?> uploadAvatar(File image) async {
    final body = await _api.uploadAvatar(image);
    final avatar = asString(body['avatar']);

    if (avatar != null) {
      _cached = null;

      final user = _session.user;
      if (user != null) {
        await _session.updateUser(user.copyWith(avatar: avatar));
      }
    }

    return avatar;
  }

  /// File a bug report.
  ///
  /// `status` is gone. It meant "open", it was always sent as "open", and a
  /// reporter does not get to close their own report - so the server sets it and
  /// the client no longer claims a say in it.
  Future<void> submitBugReport({
    required String title,
    required String message,
    required String platform,
    File? screenshot,
  }) {
    return _api.submitBugReport(
      title: title,
      message: message,
      platform: platform,
      screenshot: screenshot,
    );
  }
}
