import '../../../../core/utils/json_parsers.dart';

/// Catatan lembur karyawan.
class OvertimeEntry {
  const OvertimeEntry({
    required this.id,
    required this.date,
    required this.dayType,
    required this.status,
    required this.hoursApproved,
    this.hoursWorked,
    this.reason,
  });

  factory OvertimeEntry.fromJson(Map<String, dynamic> json) {
    return OvertimeEntry(
      id: asString(json['id']) ?? '',
      date: asString(json['date']) ?? '',
      dayType: asString(json['day_type']) ?? 'workday',
      status: asString(json['status']) ?? 'pending',
      hoursApproved: asDouble(json['hours_approved']) ?? 0.0,
      hoursWorked: asDouble(json['hours_worked']),
      reason: asString(json['reason']),
    );
  }

  final String id;
  final String date;
  final String dayType;
  final String status;
  final double hoursApproved;
  final double? hoursWorked;
  final String? reason;

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';
  bool get isPending => !isApproved && !isRejected;

  String get statusLabel => switch (status.toLowerCase()) {
    'approved' => 'Disetujui',
    'rejected' => 'Ditolak',
    'pending' || 'waiting' => 'Menunggu',
    _ => status,
  };
}
