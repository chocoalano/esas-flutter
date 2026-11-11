import '../../../../core/utils/json_parsers.dart';

class Salaries {
  int? id;
  int? userId;
  /// A decimal: `decimal:2` arrives as `"5000000.00"` (PROF-03).
  num? basicSalary;
  String? paymentType;
  dynamic createdAt;
  dynamic updatedAt;

  Salaries({
    this.id,
    this.userId,
    this.basicSalary,
    this.paymentType,
    this.createdAt,
    this.updatedAt,
  });

  factory Salaries.fromJson(Map<String, dynamic> json) => Salaries(
    // `basic_salary` is a decimal, and the field it lands in is an int. An
    // unguarded assignment threw the moment a workspace had a wage with
    // anything after the decimal point.
    id: asInt(json["id"]),
    userId: asInt(json["user_id"]),
    // `asDouble`, not `asInt`: Laravel's `decimal:2` sends a string such as
    // "5000000.00", which `int.tryParse` reads as nothing (PROF-03).
    basicSalary: asDouble(json["basic_salary"]),
    paymentType: asString(json["payment_type"]),
    createdAt: json["created_at"],
    updatedAt: json["updated_at"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "user_id": userId,
    "basic_salary": basicSalary,
    "payment_type": paymentType,
    "created_at": createdAt,
    "updated_at": updatedAt,
  };
}
