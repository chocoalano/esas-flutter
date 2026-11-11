import '../../../../core/utils/json_parsers.dart';

class GamsVisitorPass {
  const GamsVisitorPass({
    required this.id,
    required this.number,
    required this.visitorName,
    this.visitorPhone,
    this.visitorCompany,
    required this.purpose,
    required this.status,
    this.facility,
    this.checkedInAt,
    this.checkedOutAt,
    this.createdAt,
  });

  factory GamsVisitorPass.fromJson(Map<String, dynamic> json) {
    return GamsVisitorPass(
      id: asInt(json['id']) ?? 0,
      number: asString(json['number']) ?? '',
      visitorName: asString(json['visitor_name']) ?? '',
      visitorPhone: asString(json['visitor_phone']),
      visitorCompany: asString(json['visitor_company']),
      purpose: asString(json['purpose']) ?? '',
      status: asString(json['status']) ?? 'pre_register',
      facility: asString(json['facility']),
      checkedInAt: asString(json['checked_in_at']),
      checkedOutAt: asString(json['checked_out_at']),
      createdAt: asString(json['created_at']),
    );
  }

  final int id;
  final String number;
  final String visitorName;
  final String? visitorPhone;
  final String? visitorCompany;
  final String purpose;
  final String status;
  final String? facility;
  final String? checkedInAt;
  final String? checkedOutAt;
  final String? createdAt;

  String get statusLabel => switch (status.toLowerCase()) {
    'pre_register' => 'Terdaftar (Pra-Kunjungan)',
    'approved' => 'Disetujui',
    'active' => 'Sedang Berkunjung',
    'checked_out' => 'Selesai (Check-out)',
    _ => status,
  };
}
