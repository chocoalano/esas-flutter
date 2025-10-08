import 'approval.m.dart';
import 'departement.m.dart';

class Employee {
  int? id;
  int? userId;
  int? departementId;
  int? jobPositionId;
  int? jobLevelId;
  int? approvalLineId;
  int? approvalManagerId;
  DateTime? joinDate;
  DateTime? signDate;
  dynamic resignDate;
  String? bankName;
  String? bankNumber;
  String? bankHolder;
  dynamic saldoCuti;
  DateTime? createdAt;
  DateTime? updatedAt;
  Approval? approvalLine;
  Approval? approvalManager;
  Departement? departement;
  Departement? jobPosition;
  Departement? jobLevel;

  Employee({
    this.id,
    this.userId,
    this.departementId,
    this.jobPositionId,
    this.jobLevelId,
    this.approvalLineId,
    this.approvalManagerId,
    this.joinDate,
    this.signDate,
    this.resignDate,
    this.bankName,
    this.bankNumber,
    this.bankHolder,
    this.saldoCuti,
    this.createdAt,
    this.updatedAt,
    this.approvalLine,
    this.approvalManager,
    this.departement,
    this.jobPosition,
    this.jobLevel,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
    id: json["id"],
    userId: json["user_id"],
    departementId: json["departement_id"],
    jobPositionId: json["job_position_id"],
    jobLevelId: json["job_level_id"],
    approvalLineId: json["approval_line_id"],
    approvalManagerId: json["approval_manager_id"],
    joinDate: json["join_date"] == null
        ? null
        : DateTime.parse(json["join_date"]),
    signDate: json["sign_date"] == null
        ? null
        : DateTime.parse(json["sign_date"]),
    resignDate: json["resign_date"],
    bankName: json["bank_name"],
    bankNumber: json["bank_number"],
    bankHolder: json["bank_holder"],
    saldoCuti: json["saldo_cuti"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    approvalLine: json["approval_line"] == null
        ? null
        : Approval.fromJson(json["approval_line"]),
    approvalManager: json["approval_manager"] == null
        ? null
        : Approval.fromJson(json["approval_manager"]),
    departement: json["departement"] == null
        ? null
        : Departement.fromJson(json["departement"]),
    jobPosition: json["job_position"] == null
        ? null
        : Departement.fromJson(json["job_position"]),
    jobLevel: json["job_level"] == null
        ? null
        : Departement.fromJson(json["job_level"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "departement_id": departementId,
    "job_position_id": jobPositionId,
    "job_level_id": jobLevelId,
    "approval_line_id": approvalLineId,
    "approval_manager_id": approvalManagerId,
    "join_date": joinDate?.toIso8601String(),
    "sign_date": signDate?.toIso8601String(),
    "resign_date": resignDate,
    "bank_name": bankName,
    "bank_number": bankNumber,
    "bank_holder": bankHolder,
    "saldo_cuti": saldoCuti,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "approval_line": approvalLine?.toJson(),
    "approval_manager": approvalManager?.toJson(),
    "departement": departement?.toJson(),
    "job_position": jobPosition?.toJson(),
    "job_level": jobLevel?.toJson(),
  };
}
