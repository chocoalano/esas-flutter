import '../../../../core/utils/json_parsers.dart';

class EmployeeLoan {
  const EmployeeLoan({
    required this.reference,
    required this.purpose,
    required this.principal,
    required this.repaid,
    required this.outstanding,
    required this.instalmentsLeft,
    required this.instalmentAmount,
  });

  factory EmployeeLoan.fromJson(Map<String, dynamic> json) {
    return EmployeeLoan(
      reference: asString(json['reference']) ?? '',
      purpose: asString(json['purpose']) ?? '',
      principal: asDouble(json['principal']) ?? 0.0,
      repaid: asDouble(json['repaid']) ?? 0.0,
      outstanding: asDouble(json['outstanding']) ?? 0.0,
      instalmentsLeft: asInt(json['instalments_left']) ?? 0,
      instalmentAmount: asDouble(json['instalment_amount']) ?? 0.0,
    );
  }

  final String reference;
  final String purpose;
  final double principal;
  final double repaid;
  final double outstanding;
  final int instalmentsLeft;
  final double instalmentAmount;
}

class LoansResponse {
  const LoansResponse({
    required this.loans,
    required this.outstandingTotal,
  });

  factory LoansResponse.fromJson(Map<String, dynamic> json) {
    return LoansResponse(
      loans: asList(json['loans'])
          .map((item) => EmployeeLoan.fromJson(asObject(item)))
          .toList(),
      outstandingTotal: asDouble(json['outstanding_total']) ?? 0.0,
    );
  }

  final List<EmployeeLoan> loans;
  final double outstandingTotal;
}

