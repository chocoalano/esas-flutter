import '../../../../core/utils/json_parsers.dart';

class PerformancePlan {
  const PerformancePlan({
    required this.id,
    required this.cycleName,
    this.periodStart,
    this.periodEnd,
    required this.status,
    required this.statusLabel,
    required this.totalWeight,
    this.createdAt,
  });

  factory PerformancePlan.fromJson(Map<String, dynamic> json) {
    return PerformancePlan(
      id: asInt(json['id']) ?? 0,
      cycleName: asString(json['cycle_name']) ?? 'Siklus KPI',
      periodStart: asString(json['period_start']),
      periodEnd: asString(json['period_end']),
      status: asString(json['status']) ?? 'frozen',
      statusLabel: asString(json['status_label']) ?? 'Disepakati',
      totalWeight: asDouble(json['total_weight']) ?? 100.0,
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String cycleName;
  final String? periodStart;
  final String? periodEnd;
  final String status;
  final String statusLabel;
  final double totalWeight;
  final String? createdAt;
}

