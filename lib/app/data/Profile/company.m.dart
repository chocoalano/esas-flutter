class Company {
  int? id;
  String? name;
  double? latitude;
  double? longitude;
  int? radius;
  String? fullAddress;
  DateTime? createdAt;
  DateTime? updatedAt;
  dynamic deletedAt;

  Company({
    this.id,
    this.name,
    this.latitude,
    this.longitude,
    this.radius,
    this.fullAddress,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json["id"],
    name: json["name"],
    latitude: json["latitude"]?.toDouble(),
    longitude: json["longitude"]?.toDouble(),
    radius: json["radius"],
    fullAddress: json["full_address"],
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
    "name": name,
    "latitude": latitude,
    "longitude": longitude,
    "radius": radius,
    "full_address": fullAddress,
    "created_at": createdAt?.toIso8601String(),
    "updated_at": updatedAt?.toIso8601String(),
    "deleted_at": deletedAt,
  };
}
