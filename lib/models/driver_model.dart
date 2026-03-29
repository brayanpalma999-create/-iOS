import "location_model.dart";
import "user_model.dart";

class DriverModel extends UserModel {
  const DriverModel({
    required super.id,
    required super.name,
    required this.location,
    this.status = "Disponible",
    this.currentTripId,
    super.isOnline,
  }) : super(role: UserRole.driver);

  final LocationModel location;
  final String status;
  final String? currentTripId;

  @override
  DriverModel copyWith({
    String? id,
    String? name,
    UserRole? role,
    bool? isOnline,
    LocationModel? location,
    String? status,
    String? currentTripId,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      status: status ?? this.status,
      currentTripId: currentTripId ?? this.currentTripId,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    "location": location.toJson(),
    "status": status,
    "currentTripId": currentTripId,
  };

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json["id"].toString(),
      name: json["name"].toString(),
      location: LocationModel.fromJson(
        (json["location"] as Map?)?.cast<String, dynamic>() ??
            {"latitude": 19.4326, "longitude": -99.1332},
      ),
      status: json["status"]?.toString() ?? "Disponible",
      currentTripId: json["currentTripId"]?.toString(),
      isOnline: json["isOnline"] as bool? ?? true,
    );
  }
}
