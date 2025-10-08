class Salaries {
  int? id;
  int? userId;
  int? basicSalary;
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
    id: json["id"],
    userId: json["user_id"],
    basicSalary: json["basic_salary"],
    paymentType: json["payment_type"],
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
