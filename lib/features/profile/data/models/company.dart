import '../../../../core/utils/json_parsers.dart';

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

  /// The coordinates come back as decimal *strings* from the HRIS, so
  /// `json["latitude"]?.toDouble()` — which assumes a num — was a crash on real
  /// data. These are for the profile screen; attendance reads its geofence from
  /// `attendance/context`, fresh, because a coordinate cached from an old
  /// session is the wrong geofence the day the office moves.
  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: asInt(json["id"]),
    name: asString(json["name"]),
    latitude: asDouble(json["latitude"]),
    longitude: asDouble(json["longitude"]),
    radius: asInt(json["radius"]),
    fullAddress: asString(json["full_address"]),
    createdAt: asDate(json["created_at"]),
    updatedAt: asDate(json["updated_at"]),
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
