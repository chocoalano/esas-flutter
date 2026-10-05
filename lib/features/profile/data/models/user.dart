import 'dart:convert';

import 'address.m.dart';
import 'company.m.dart';
import 'detail.m.dart';
import 'employe.m.dart';
import 'family.m.dart';
import 'foeducation.m.dart'; // Make sure this defines FormalEducation
import 'ineducation.m.dart'; // Make sure this defines InformalEducationModel
import 'salary.m.dart';
import 'workexp.m.dart'; // Make sure this defines WorkExperienceModel

User userFromJson(String str) => User.fromJson(json.decode(str));

String userToJson(User data) => json.encode(data.toJson());

class User {
  int? id;
  int? companyId;
  String? name;
  String? nip;
  String? email;
  DateTime? emailVerifiedAt;
  String? avatar;
  String? status;
  String? deviceId;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;
  Company? company;
  Details? details;
  Address? address;
  Salaries? salaries;
  List<Family>? families;
  List<FormalEducation>? formalEducations; // Correct type
  List<InformalEducationModel>? informalEducations; // Correct type
  List<WorkExperienceModel>? workExperiences; // Correct type
  Employee? employee;

  User({
    this.id,
    this.companyId,
    this.name,
    this.nip,
    this.email,
    this.emailVerifiedAt,
    this.avatar,
    this.status,
    this.deviceId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.company,
    this.details,
    this.address,
    this.salaries,
    this.families,
    this.formalEducations,
    this.informalEducations,
    this.workExperiences,
    this.employee,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    companyId: json["company_id"],
    name: json["name"],
    nip: json["nip"],
    email: json["email"],
    emailVerifiedAt: json["email_verified_at"] == null
        ? null
        : DateTime.parse(json["email_verified_at"]),
    avatar: json["avatar"],
    status: json["status"],
    deviceId: json["device_id"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
    company: json["company"] == null ? null : Company.fromJson(json["company"]),
    details: json["details"] == null ? null : Details.fromJson(json["details"]),
    address: json["address"] == null ? null : Address.fromJson(json["address"]),
    salaries: json["salaries"] == null
        ? null
        : Salaries.fromJson(json["salaries"]),
    families: json["families"] == null
        ? []
        : List<Family>.from(json["families"]!.map((x) => Family.fromJson(x))),
    // --- FIXES ARE HERE ---
    formalEducations: json["formal_educations"] == null
        ? []
        : List<FormalEducation>.from(
            json["formal_educations"]!.map((x) => FormalEducation.fromJson(x)),
          ),
    informalEducations: json["informal_educations"] == null
        ? []
        : List<InformalEducationModel>.from(
            json["informal_educations"]!.map(
              (x) => InformalEducationModel.fromJson(x),
            ),
          ),
    workExperiences: json["work_experiences"] == null
        ? []
        : List<WorkExperienceModel>.from(
            json["work_experiences"]!.map(
              (x) => WorkExperienceModel.fromJson(x),
            ),
          ),
    // --- END FIXES ---
    employee: json["employee"] == null
        ? null
        : Employee.fromJson(json["employee"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "company_id": companyId,
    "name": name,
    "nip": nip,
    "email": email,
    "email_verified_at": emailVerifiedAt?.toIso8601String(),
    "avatar": avatar,
    "status": status,
    "device_id": deviceId,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
    "company": company?.toJson(),
    "details": details?.toJson(),
    "address": address?.toJson(),
    "salaries": salaries?.toJson(),
    "families": families == null
        ? []
        : List<dynamic>.from(families!.map((x) => x.toJson())),
    // --- FIXES ARE HERE ---
    "formal_educations": formalEducations == null
        ? []
        : List<dynamic>.from(formalEducations!.map((x) => x.toJson())),
    "informal_educations": informalEducations == null
        ? []
        : List<dynamic>.from(informalEducations!.map((x) => x.toJson())),
    "work_experiences": workExperiences == null
        ? []
        : List<dynamic>.from(workExperiences!.map((x) => x.toJson())),
    // --- END FIXES ---
    "employee": employee?.toJson(),
  };
}
