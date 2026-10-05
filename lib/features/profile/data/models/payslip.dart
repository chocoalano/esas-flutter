import '../../../../core/utils/json_parsers.dart';

class PayslipLine {
  PayslipLine.fromJson(Map<String, dynamic> json)
    : label = asString(json['label']) ?? '',
      amount = asDouble(json['amount']) ?? 0;
  final String label;
  final double amount;
}

class Payslip {
  Payslip.fromJson(Map<String, dynamic> json)
    : id = asInt(json['id']) ?? 0,
      period = asObject(json['period']),
      employee = asObject(json['employee']),
      bank = asObject(json['bank']),
      grossIncome =
          asDouble(json['earned_income'] ?? json['gross_income']) ?? 0,
      totalDeduction =
          asDouble(json['applied_deduction'] ?? json['total_deduction']) ?? 0,
      takeHomePay = asDouble(json['take_home_pay']) ?? 0,
      earnings = asModelList(json['earnings'], PayslipLine.fromJson),
      deductions = asModelList(json['deductions'], PayslipLine.fromJson) {
    if (id <= 0 ||
        period.isEmpty ||
        asDouble(json['take_home_pay']) == null ||
        asDouble(json['earned_income'] ?? json['gross_income']) == null ||
        asDouble(json['applied_deduction'] ?? json['total_deduction']) ==
            null ||
        !grossIncome.isFinite ||
        !totalDeduction.isFinite ||
        !takeHomePay.isFinite) {
      throw const FormatException('Invalid payslip amounts');
    }
  }
  final int id;
  final Map<String, dynamic> period, employee, bank;
  final double grossIncome, totalDeduction, takeHomePay;
  final List<PayslipLine> earnings, deductions;
  String get code => asString(period['code']) ?? 'Slip gaji';
  String get runLabel => asString(period['run_label']) ?? 'Gaji bulanan';
  String get statusLabel =>
      period['status'] == 'paid' ? 'Dibayar' : 'Disetujui';
}

class PayslipPage {
  PayslipPage.fromJson(Map<String, dynamic> json)
    : rows = _parseSlips(json['data']),
      currentPage = asInt(json['current_page']) ?? 1,
      lastPage = asInt(json['last_page']) ?? 1;
  final List<Payslip> rows;
  final int currentPage, lastPage;
  bool get hasMore => currentPage < lastPage;
}

List<Payslip> _parseSlips(Object? value) {
  if (value is! List) throw const FormatException('Invalid payslip page');
  return value.map((row) => Payslip.fromJson(asObject(row))).toList();
}
