import '../../../../core/utils/json_parsers.dart';

class CashAdvance {
  const CashAdvance({
    required this.reference,
    required this.purpose,
    required this.amount,
    this.disbursedAt,
  });

  factory CashAdvance.fromJson(Map<String, dynamic> json) {
    return CashAdvance(
      reference: asString(json['reference']) ?? '',
      purpose: asString(json['purpose']) ?? '',
      amount: asDouble(json['amount']) ?? 0.0,
      disbursedAt: asString(json['disbursed_at']),
    );
  }

  final String reference;
  final String purpose;
  final double amount;
  final String? disbursedAt;
}

class AdvancesResponse {
  const AdvancesResponse({
    required this.advances,
    required this.unaccountedTotal,
  });

  factory AdvancesResponse.fromJson(Map<String, dynamic> json) {
    return AdvancesResponse(
      advances: asList(json['advances'])
          .map((item) => CashAdvance.fromJson(asObject(item)))
          .toList(),
      unaccountedTotal: asDouble(json['unaccounted_total']) ?? 0.0,
    );
  }

  final List<CashAdvance> advances;
  final double unaccountedTotal;
}

