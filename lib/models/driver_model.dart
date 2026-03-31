import "location_model.dart";
import "user_model.dart";

const Object _driverModelUnset = Object();

class DriverModel extends UserModel {
  const DriverModel({
    required super.id,
    this.intercomId,
    required super.name,
    required super.legalName,
    required super.email,
    required super.phoneNumber,
    required super.address,
    required super.governmentId,
    super.languageCode,
    super.avatarPath,
    required this.location,
    this.status = "Disponible",
    this.currentTripId,
    super.isOnline,
  }) : super(role: UserRole.driver);

  final LocationModel location;
  final String? intercomId;
  final String status;
  final String? currentTripId;

  @override
  DriverModel copyWith({
    String? id,
    String? intercomId,
    String? name,
    UserRole? role,
    String? legalName,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
    String? languageCode,
    bool? isOnline,
    String? avatarPath,
    LocationModel? location,
    String? status,
    Object? currentTripId = _driverModelUnset,
  }) {
    return DriverModel(
      id: id ?? this.id,
      intercomId: intercomId ?? this.intercomId,
      name: name ?? this.name,
      legalName: legalName ?? this.legalName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      governmentId: governmentId ?? this.governmentId,
      languageCode: languageCode ?? this.languageCode,
      avatarPath: avatarPath ?? this.avatarPath,
      location: location ?? this.location,
      status: status ?? this.status,
      currentTripId: identical(currentTripId, _driverModelUnset)
          ? this.currentTripId
          : currentTripId as String?,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...super.toJson(),
    "intercomId": intercomId,
    "location": location.toJson(),
    "status": status,
    "currentTripId": currentTripId,
  };

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json["id"].toString(),
      intercomId: json["intercomId"]?.toString(),
      name: json["name"].toString(),
      legalName:
          json["legalName"]?.toString() ?? json["name"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      phoneNumber: json["phoneNumber"]?.toString() ?? "",
      address: json["address"]?.toString() ?? "",
      governmentId: json["governmentId"]?.toString() ?? "",
      languageCode: json["languageCode"]?.toString() ?? "es",
      location: LocationModel.fromJson(
        (json["location"] as Map?)?.cast<String, dynamic>() ??
            {"latitude": 0, "longitude": 0},
      ),
      status: json["status"]?.toString() ?? "Disponible",
      currentTripId: json["currentTripId"]?.toString(),
      isOnline: json["isOnline"] as bool? ?? true,
      avatarPath: json["avatarPath"]?.toString(),
    );
  }
}
