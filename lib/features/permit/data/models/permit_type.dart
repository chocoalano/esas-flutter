class PermitType {
  int? id;
  String? type;
  bool? isPayed;
  bool? approveLine;
  bool? approveManager;
  bool? approveHr;
  bool? withFile;
  bool? showMobile;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;

  PermitType({
    this.id,
    this.type,
    this.isPayed,
    this.approveLine,
    this.approveManager,
    this.approveHr,
    this.withFile,
    this.showMobile,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory PermitType.fromJson(Map<String, dynamic> json) => PermitType(
    id: json["id"],
    type: json["type"],
    isPayed: json["is_payed"],
    approveLine: json["approve_line"],
    approveManager: json["approve_manager"],
    approveHr: json["approve_hr"],
    withFile: json["with_file"],
    showMobile: json["show_mobile"],
    createdAt: json["created_at"] == null
        ? null
        : DateTime.parse(json["created_at"]),
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"]),
    deletedAt: json["deleted_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "type": type,
    "is_payed": isPayed,
    "approve_line": approveLine,
    "approve_manager": approveManager,
    "approve_hr": approveHr,
    "with_file": withFile,
    "show_mobile": showMobile,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
  };
}
