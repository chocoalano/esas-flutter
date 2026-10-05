import 'dart:io';

import '../../../../core/config/api_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/idempotency_key.dart';
import '../../../../core/network/upload.dart';

class ProfileApiService {
  const ProfileApiService(this._client);

  final ApiClient _client;

  /// The whole employee record behind the five profile tabs: user, company,
  /// employment, personal detail, addresses, families, educations, experiences.
  ///
  /// This is what replaced reading domain data off the login payload. Signing in
  /// says who you are; it does not carry a record that HR can change underneath
  /// you.
  ///
  /// The company coordinates here are for the profile screen. Attendance must
  /// not read its geofence from them — it has `attendance/context`, asked fresh
  /// at the moment of clocking, and a coordinate cached from an old session is
  /// the wrong geofence the day the office moves.
  Future<Map<String, dynamic>> profile() =>
      _client.getObject(ApiRoutes.profile);

  /// Who this token belongs to — the light answer, for the splash probe.
  Future<Map<String, dynamic>> currentUser() =>
      _client.getObject(ApiRoutes.currentUser);

  /// Wage components: salary, grade, bank details, and the runs already paid.
  ///
  /// Detailed slips are read through [payslips] and [payslip].
  Future<Map<String, dynamic>> payroll() =>
      _client.getObject(ApiRoutes.payroll);

  Future<Map<String, dynamic>> payslips({int page = 1}) => _client.getObject(
    ApiRoutes.payslips,
    query: {'page': page, 'per_page': 12},
  );

  Future<Map<String, dynamic>> payslip(int id) =>
      _client.getObject(ApiRoutes.payslip(id));
  Future<Map<String, dynamic>> payslipPdf(int id) =>
      _client.getObject(ApiRoutes.payslipPdf(id));

  Future<Map<String, dynamic>> attendanceSummary({int? year, int? month}) =>
      _client.getObject(
        ApiRoutes.attendanceSummary,
        query: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );

  /// Replace this person's photograph.
  ///
  /// The one write in self-service that touches the employee record, and
  /// deliberately the narrowest possible. Name, employee number, department and
  /// pay stay HR's: a workforce that can edit its own employment record is not
  /// a self-service feature.
  Future<Map<String, dynamic>> uploadAvatar(File image) => _client.postForm(
    ApiRoutes.avatar,
    const {},
    files: {'file': Upload.file(image)},
  );

  Future<Map<String, dynamic>> submitBugReport({
    required String title,
    required String message,
    required String platform,
    File? screenshot,
    String? idempotencyKey,
  }) {
    return _client.postForm(
      ApiRoutes.bugReports,
      {'title': title, 'message': message, 'platform': platform},
      files: {if (screenshot != null) 'image': Upload.file(screenshot)},
      // Accepted rather than required on this endpoint: a duplicate bug report
      // is a nuisance somebody closes. Sent anyway, because a report filed twice
      // from a flaky connection is still noise nobody asked for.
      headers: IdempotencyKey.headerFor(
        idempotencyKey ?? IdempotencyKey.mint(),
      ),
    );
  }
}
