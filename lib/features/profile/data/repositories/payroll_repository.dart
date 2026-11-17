import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/json_parsers.dart';
import '../../../../core/network/api_exception.dart';
import '../models/cash_advance.dart';
import '../models/company_policy.dart';
import '../models/device_session.dart';
import '../models/employee_loan.dart';
import '../models/expense_claim.dart';
import '../models/payslip.dart';
import '../models/performance_plan.dart';
import '../models/travel_request.dart';
import '../models/worker_skill.dart';
import '../services/payslip_step_up.dart';
import '../services/profile_api_service.dart';

class PayrollRepository {
  /// [askPassword] is how the person is asked to re-enter their password when
  /// the server wants a step-up (WP-01 Final, G5); without one, a step-up
  /// refusal reaches the caller as it is.
  PayrollRepository(
    this._api, {
    PayslipPasswordPrompt? askPassword,
    PayslipGrantCache? grants,
  }) : _askPassword = askPassword,
       _grants = grants ?? PayslipGrantCache.instance;
  final ProfileApiService _api;
  final PayslipPasswordPrompt? _askPassword;
  final PayslipGrantCache _grants;

  Future<PayslipPage> page({int page = 1}) async {
    final json = await _viewing(
      (grant) => _api.payslips(page: page, grant: grant),
    );
    try {
      return PayslipPage.fromJson(json);
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  Future<Payslip> slip(int id) async {
    final json = await _viewing((grant) => _api.payslip(id, grant: grant));
    try {
      return Payslip.fromJson(asObject(json['slip']));
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  /// The payslip as an encrypted PDF and the password that opens it (WP-01
  /// Final, G6). The password is shown to the person once and kept nowhere;
  /// a file the server did not say is encrypted is refused, never saved.
  Future<({String filename, Uint8List bytes, String password})> pdf(
    int id,
  ) async {
    final response = await _downloading(id);
    final bytes = base64Decode(asString(response['content_base64']) ?? '');
    if (bytes.length < 5 || utf8.decode(bytes.take(5).toList()) != '%PDF-') {
      throw const FormatException('Invalid payslip PDF');
    }
    final password = asString(response['password']) ?? '';
    if (response['encrypted'] != true || password.isEmpty) {
      throw const FormatException('Unencrypted payslip PDF');
    }
    return (filename: 'slip-gaji-$id.pdf', bytes: bytes, password: password);
  }

  /// A read of pay: with the cached view grant first, and - when the server
  /// asks for the password - once more with a fresh one.
  Future<Map<String, dynamic>> _viewing(
    Future<Map<String, dynamic>> Function(String? grant) read,
  ) async {
    try {
      return await read(_grants.viewGrant);
    } on ApiException catch (error) {
      if (!PayslipStepUp.asks(error)) rethrow;
      _grants.clear();
      return read(await _unlock(PayslipStepUp.view));
    }
  }

  /// A PDF needs its own single-use grant for that payslip; the server's
  /// answer to the first try says whether one is needed at all (a workspace
  /// with PDF download switched off answers that instead).
  Future<Map<String, dynamic>> _downloading(int id) async {
    try {
      return await _api.payslipPdf(id);
    } on ApiException catch (error) {
      if (!PayslipStepUp.asks(error)) rethrow;
      final grant = await _unlock(PayslipStepUp.download, slipId: id);
      return _api.payslipPdf(id, grant: grant);
    }
  }

  Future<String> _unlock(String purpose, {int? slipId}) async {
    final ask = _askPassword;
    final password = ask == null ? null : await ask();
    if (password == null || password.isEmpty) {
      throw const ApiException(
        'Masukkan kata sandi Anda untuk membuka data gaji.',
        status: 403,
        code: 'payslip_step_up_cancelled',
      );
    }
    final response = await _api.payslipStepUp(
      password: password,
      purpose: purpose,
      slipId: slipId,
    );
    final grant = asString(response['grant']) ?? '';
    if (grant.isEmpty) {
      throw const ApiException('Data gaji tidak dapat dibuka. Coba lagi.');
    }
    if (purpose == PayslipStepUp.view) {
      final expiresAt = DateTime.tryParse(
        asString(response['expires_at']) ?? '',
      );
      if (expiresAt != null) _grants.remember(grant, expiresAt.toLocal());
    }
    return grant;
  }

  /// Sisa pinjaman karyawan.
  Future<LoansResponse> loans() async {
    final response = await _viewing((grant) => _api.loans(grant: grant));
    return LoansResponse.fromJson(response);
  }

  /// Kasbon karyawan yang belum dipertanggungjawabkan.
  Future<AdvancesResponse> advances() async {
    final response = await _viewing((grant) => _api.advances(grant: grant));
    return AdvancesResponse.fromJson(response);
  }

  /// Klaim biaya reimbursement karyawan.
  Future<List<ExpenseClaim>> expenseClaims({int page = 1}) async {
    final response = await _api.expenseClaims(page: page);
    final data = asList(response['data']);
    return data.map((item) => ExpenseClaim.fromJson(asObject(item))).toList();
  }

  /// Permohonan perjalanan dinas karyawan.
  Future<List<TravelRequest>> travelRequests({int page = 1}) async {
    final response = await _api.travelRequests(page: page);
    final data = asList(response['data']);
    return data.map((item) => TravelRequest.fromJson(asObject(item))).toList();
  }

  Future<void> submitExpenseClaim({
    required String title,
    required List<Map<String, dynamic>> items,
  }) async {
    await _api.submitExpenseClaim(title: title, items: items);
  }

  Future<void> submitTravelRequest({
    required String destination,
    required String purpose,
    required String departureDate,
    required String returnDate,
    double? estimatedCost,
  }) async {
    await _api.submitTravelRequest(
      destination: destination,
      purpose: purpose,
      departureDate: departureDate,
      returnDate: returnDate,
      estimatedCost: estimatedCost,
    );
  }

  Future<List<PerformancePlan>> performancePlans({int page = 1}) async {
    final response = await _api.performancePlans(page: page);
    final data = asList(response['data']);
    return data
        .map((item) => PerformancePlan.fromJson(asObject(item)))
        .toList();
  }

  Future<List<CompanyPolicy>> companyPolicies({
    String? query,
    int page = 1,
  }) async {
    final response = await _api.companyPolicies(query: query, page: page);
    final data = asList(response['data']);
    return data.map((item) => CompanyPolicy.fromJson(asObject(item))).toList();
  }

  Future<List<WorkerSkill>> skills() async {
    final response = await _api.skills();
    final data = asList(response['data']);
    return data.map((item) => WorkerSkill.fromJson(asObject(item))).toList();
  }

  Future<List<DeviceSession>> devices() async {
    final response = await _api.devices();
    final list = asList(response['devices']);
    return list.map((item) => DeviceSession.fromJson(asObject(item))).toList();
  }

  Future<void> forgetDevice(String deviceId) async {
    await _api.forgetDevice(deviceId);
  }
}
