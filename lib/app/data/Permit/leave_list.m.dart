import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'leave_type.m.dart'; // pastikan benar

// -------------------- Helpers null-safe --------------------
int _asInt(Map<String, dynamic> j, String k, {int? def}) {
  final v = j[k];
  if (v == null) return def ?? 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? (def ?? 0);
}

String? _asStringN(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v == null) return null;
  return v.toString();
}

String _asString(Map<String, dynamic> j, String k, {String def = ''}) {
  return _asStringN(j, k) ?? def;
}

DateTime? _asDate(Map<String, dynamic> j, String k) {
  final s = _asStringN(j, k);
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s);
}

Map<String, dynamic>? _asMapN(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v == null || v is! Map) return null;
  return v.cast<String, dynamic>();
}

List<dynamic> _asList(Map<String, dynamic> j, String k) {
  final v = j[k];
  if (v is List) return v;
  return const [];
}

// -------------------- Models --------------------
class Permit {
  final int id;
  final String permitNumbers;
  final int userId;
  final int permitTypeId;
  final int userTimeworkScheduleId;

  final String? timeinAdjust;
  final String? timeoutAdjust;
  final int? currentShiftId;
  final int? adjustShiftId;

  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;

  final String? notes;
  final String? file;

  final String? createdAt; // biarkan String? jika API kirim string
  final String? updatedAt;
  final String? deletedAt;

  final User? user; // nullable
  final LeaveType? permitType; // nullable
  final List<Approval> approvals; // default []
  final UserTimeworkSchedule? userTimeworkSchedule; // nullable

  Permit({
    required this.id,
    required this.permitNumbers,
    required this.userId,
    required this.permitTypeId,
    required this.userTimeworkScheduleId,
    this.timeinAdjust,
    this.timeoutAdjust,
    this.currentShiftId,
    this.adjustShiftId,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.notes,
    this.file,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.user,
    this.permitType,
    this.approvals = const [],
    this.userTimeworkSchedule,
  });

  factory Permit.fromJson(Map<String, dynamic> json) {
    final userMap = _asMapN(json, 'user');
    final permitTypeMap = _asMapN(json, 'permit_type');
    final utsMap = _asMapN(json, 'user_timework_schedule');

    return Permit(
      id: _asInt(json, 'id'),
      permitNumbers: _asString(json, 'permit_numbers'),
      userId: _asInt(json, 'user_id'),
      permitTypeId: _asInt(json, 'permit_type_id'),
      userTimeworkScheduleId: _asInt(json, 'user_timework_schedule_id'),
      timeinAdjust: _asStringN(json, 'timein_adjust'),
      timeoutAdjust: _asStringN(json, 'timeout_adjust'),
      currentShiftId: json['current_shift_id'] == null
          ? null
          : _asInt(json, 'current_shift_id'),
      adjustShiftId: json['adjust_shift_id'] == null
          ? null
          : _asInt(json, 'adjust_shift_id'),
      startDate: _asDate(json, 'start_date'),
      endDate: _asDate(json, 'end_date'),
      startTime: _asStringN(json, 'start_time'),
      endTime: _asStringN(json, 'end_time'),
      notes: _asStringN(json, 'notes'),
      file: _asStringN(json, 'file'),
      createdAt: _asStringN(json, 'created_at'),
      updatedAt: _asStringN(json, 'updated_at'),
      deletedAt: _asStringN(json, 'deleted_at'),
      user: userMap == null ? null : User.fromJson(userMap),
      permitType: permitTypeMap == null
          ? null
          : LeaveType.fromJson(permitTypeMap),
      approvals: _asList(json, 'approvals')
          .whereType<Map>()
          .map((e) => Approval.fromJson(e.cast<String, dynamic>()))
          .toList(),
      userTimeworkSchedule: utsMap == null
          ? null
          : UserTimeworkSchedule.fromJson(utsMap),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'permit_numbers': permitNumbers,
    'user_id': userId,
    'permit_type_id': permitTypeId,
    'user_timework_schedule_id': userTimeworkScheduleId,
    if (timeinAdjust != null) 'timein_adjust': timeinAdjust,
    if (timeoutAdjust != null) 'timeout_adjust': timeoutAdjust,
    if (currentShiftId != null) 'current_shift_id': currentShiftId,
    if (adjustShiftId != null) 'adjust_shift_id': adjustShiftId,
    if (startDate != null)
      'start_date': startDate!.toIso8601String().split('T').first,
    if (endDate != null)
      'end_date': endDate!.toIso8601String().split('T').first,
    if (startTime != null) 'start_time': startTime,
    if (endTime != null) 'end_time': endTime,
    if (notes != null) 'notes': notes,
    if (file != null) 'file': file,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
    if (deletedAt != null) 'deleted_at': deletedAt,
    if (user != null) 'user': user!.toJson(),
    if (permitType != null) 'permit_type': permitType!.toJson(),
    'approvals': approvals.map((e) => e.toJson()).toList(),
    if (userTimeworkSchedule != null)
      'user_timework_schedule': userTimeworkSchedule!.toJson(),
  };

  /// Parse list of Permits from JSON string (aman bila bukan array)
  static List<Permit> listFromJson(String jsonString) {
    final decoded = json.decode(jsonString);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Permit.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Durasi inklusif (hari), aman jika tanggal null
  int get durationInDays {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return 0;
    try {
      return end.difference(start).inDays + 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating duration for permit ID $id: $e');
      }
      return 0;
    }
  }
}

class User {
  final int id;
  final int companyId;
  final String name;
  final String nip;
  final String email;
  final String? emailVerifiedAt;
  final String? avatar;
  final String? status;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? deletedAt;

  User({
    required this.id,
    required this.companyId,
    required this.name,
    required this.nip,
    required this.email,
    this.emailVerifiedAt,
    this.avatar,
    this.status,
    this.deviceId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _asInt(json, 'id'),
      companyId: _asInt(json, 'company_id'),
      name: _asString(json, 'name'),
      nip: _asString(json, 'nip'),
      email: _asString(json, 'email'),
      emailVerifiedAt: _asStringN(json, 'email_verified_at'),
      avatar: _asStringN(json, 'avatar'),
      status: _asStringN(json, 'status'),
      deviceId: _asStringN(json, 'device_id'),
      createdAt: _asDate(json, 'created_at'),
      updatedAt: _asDate(json, 'updated_at'),
      deletedAt: _asStringN(json, 'deleted_at'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'company_id': companyId,
    'name': name,
    'nip': nip,
    'email': email,
    if (emailVerifiedAt != null) 'email_verified_at': emailVerifiedAt,
    if (avatar != null) 'avatar': avatar,
    if (status != null) 'status': status,
    if (deviceId != null) 'device_id': deviceId,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (deletedAt != null) 'deleted_at': deletedAt,
  };
}

class Approval {
  final int id;
  final int permitId;
  final int userId;
  final String? userType;
  final String? userApprove;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;

  Approval({
    required this.id,
    required this.permitId,
    required this.userId,
    this.userType,
    this.userApprove,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.status,
  });

  factory Approval.fromJson(Map<String, dynamic> json) => Approval(
    id: _asInt(json, 'id'),
    permitId: _asInt(json, 'permit_id'),
    userId: _asInt(json, 'user_id'),
    userType: _asStringN(json, 'user_type'),
    userApprove: _asStringN(json, 'user_approve'),
    notes: _asStringN(json, 'notes'),
    createdAt: _asDate(json, 'created_at'),
    updatedAt: _asDate(json, 'updated_at'),
    status: _asStringN(json, 'status'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'permit_id': permitId,
    'user_id': userId,
    if (userType != null) 'user_type': userType,
    if (userApprove != null) 'user_approve': userApprove,
    if (notes != null) 'notes': notes,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    if (status != null) 'status': status,
  };
}

class UserTimeworkSchedule {
  final int id;
  final int userId;
  final int timeWorkId;
  final DateTime? workDay;
  final String? createdAt;
  final String? updatedAt;

  UserTimeworkSchedule({
    required this.id,
    required this.userId,
    required this.timeWorkId,
    this.workDay,
    this.createdAt,
    this.updatedAt,
  });

  factory UserTimeworkSchedule.fromJson(Map<String, dynamic> json) =>
      UserTimeworkSchedule(
        id: _asInt(json, 'id'),
        userId: _asInt(json, 'user_id'),
        timeWorkId: _asInt(json, 'time_work_id'),
        workDay: _asDate(json, 'work_day'),
        createdAt: _asStringN(json, 'created_at'),
        updatedAt: _asStringN(json, 'updated_at'),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'time_work_id': timeWorkId,
    if (workDay != null)
      'work_day': workDay!.toIso8601String().split('T').first,
    if (createdAt != null) 'created_at': createdAt,
    if (updatedAt != null) 'updated_at': updatedAt,
  };
}
