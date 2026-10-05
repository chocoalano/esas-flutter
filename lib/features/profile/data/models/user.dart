import '../../../../core/utils/json_parsers.dart';

import 'dart:convert';

import 'address.dart';
import 'company.dart';
import 'detail.dart';
import 'employe.dart';
import 'family.dart';
import 'foeducation.dart'; // Make sure this defines FormalEducation
import 'ineducation.dart'; // Make sure this defines InformalEducationModel
import 'salary.dart';
import 'workexp.dart'; // Make sure this defines WorkExperienceModel

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

  /// Built from the `/profile` payload, reshaped by `ProfileRepository`.
  ///
  /// Every read is null-safe. It used to be a wall of `json["x"]` assignments
  /// and `DateTime.parse` calls that threw on an absent or retyped field, and
  /// `Company.fromJson(json["company"])` was the one that actually fired: the
  /// session endpoint flattens `company` to its *name*, so feeding this model a
  /// `/auth/me` body raised a "String is not a subtype of Map" type error
  /// before the profile screen drew a pixel.
  ///
  /// The nested objects are read through [asObject] for the same reason: a
  /// string where an object was expected now yields an empty record rather than
  /// a crash.
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: asInt(json["id"]),
    companyId: asInt(json["company_id"]),
    name: asString(json["name"]),
    nip: asString(json["nip"]),
    email: asString(json["email"]),
    emailVerifiedAt: asDate(json["email_verified_at"]),
    avatar: asString(json["avatar"]),
    status: asString(json["status"]),
    deviceId: asString(json["device_id"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
    deletedAt: json["deleted_at"],
    company: json["company"] is Map
        ? Company.fromJson(asObject(json["company"]))
        : null,
    details: json["details"] is Map
        ? Details.fromJson(asObject(json["details"]))
        : null,
    address: json["address"] is Map
        ? Address.fromJson(asObject(json["address"]))
        : null,
    salaries: json["salaries"] is Map
        ? Salaries.fromJson(asObject(json["salaries"]))
        : null,
    families: asModelList(json["families"], Family.fromJson),
    formalEducations: asModelList(
      json["formal_educations"],
      FormalEducation.fromJson,
    ),
    informalEducations: asModelList(
      json["informal_educations"],
      InformalEducationModel.fromJson,
    ),
    workExperiences: asModelList(
      json["work_experiences"],
      WorkExperienceModel.fromJson,
    ),
    employee: json["employee"] is Map
        ? Employee.fromJson(asObject(json["employee"]))
        : null,
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
