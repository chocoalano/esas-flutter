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
import '../services/profile_api_service.dart';

class PayrollRepository {
  const PayrollRepository(this._api);
  final ProfileApiService _api;
  Future<PayslipPage> page({int page = 1}) async {
    try {
      return PayslipPage.fromJson(await _api.payslips(page: page));
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  Future<Payslip> slip(int id) async {
    try {
      return Payslip.fromJson(asObject((await _api.payslip(id))['slip']));
    } on FormatException {
      throw const ApiException(
        'Data slip gaji tidak valid. Silakan coba lagi.',
      );
    }
  }

  Future<({String filename, Uint8List bytes})> pdf(int id) async {
    final response = await _api.payslipPdf(id);
    final bytes = base64Decode(asString(response['content_base64']) ?? '');
    if (bytes.length < 5 || utf8.decode(bytes.take(5).toList()) != '%PDF-') {
      throw const FormatException('Invalid payslip PDF');
    }
    return (filename: 'slip-gaji-$id.pdf', bytes: bytes);
  }

  /// Sisa pinjaman karyawan.
  Future<LoansResponse> loans() async {
    final response = await _api.loans();
    return LoansResponse.fromJson(response);
  }

  /// Kasbon karyawan yang belum dipertanggungjawabkan.
  Future<AdvancesResponse> advances() async {
    final response = await _api.advances();
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
    return data.map((item) => PerformancePlan.fromJson(asObject(item))).toList();
  }

  Future<List<CompanyPolicy>> companyPolicies({String? query, int page = 1}) async {
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
