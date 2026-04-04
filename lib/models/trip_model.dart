import "location_model.dart";

class RouteStepModel {
  const RouteStepModel({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.roadName,
    this.maneuverType,
    this.maneuverModifier,
    this.location,
  });

  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String? roadName;
  final String? maneuverType;
  final String? maneuverModifier;
  final LocationModel? location;

  RouteStepModel copyWith({
    String? instruction,
    double? distanceMeters,
    double? durationSeconds,
    String? roadName,
    String? maneuverType,
    String? maneuverModifier,
    LocationModel? location,
  }) {
    return RouteStepModel(
      instruction: instruction ?? this.instruction,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      roadName: roadName ?? this.roadName,
      maneuverType: maneuverType ?? this.maneuverType,
      maneuverModifier: maneuverModifier ?? this.maneuverModifier,
      location: location ?? this.location,
    );
  }

  Map<String, dynamic> toJson() => {
    "instruction": instruction,
    "distanceMeters": distanceMeters,
    "durationSeconds": durationSeconds,
    "roadName": roadName,
    "maneuverType": maneuverType,
    "maneuverModifier": maneuverModifier,
    "location": location?.toJson(),
  };

  factory RouteStepModel.fromJson(Map<String, dynamic> json) {
    return RouteStepModel(
      instruction: json["instruction"]?.toString() ?? "",
      distanceMeters: (json["distanceMeters"] as num?)?.toDouble() ?? 0,
      durationSeconds: (json["durationSeconds"] as num?)?.toDouble() ?? 0,
      roadName: json["roadName"]?.toString(),
      maneuverType: json["maneuverType"]?.toString(),
      maneuverModifier: json["maneuverModifier"]?.toString(),
      location: (json["location"] is Map)
          ? LocationModel.fromJson((json["location"] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class TripModel {
  const TripModel({
    required this.id,
    required this.driverId,
    this.driverIntercomId,
    required this.origin,
    required this.destination,
    required this.status,
    required this.createdAt,
    this.distanceMiles = 0,
    this.durationMinutes = 0,
    this.fareUsd = 0,
    this.routePoints = const <LocationModel>[],
    this.routeSteps = const <RouteStepModel>[],
    this.originLocation,
    this.destinationLocation,
  });

  final String id;
  final String driverId;
  final String? driverIntercomId;
  final String origin;
  final String destination;
  final String status;
  final DateTime createdAt;
  final double distanceMiles;
  final double durationMinutes;
  final double fareUsd;
  final List<LocationModel> routePoints;
  final List<RouteStepModel> routeSteps;
  final LocationModel? originLocation;
  final LocationModel? destinationLocation;

  TripModel copyWith({
    String? id,
    String? driverId,
    Object? driverIntercomId = _tripModelUnset,
    String? origin,
    String? destination,
    String? status,
    DateTime? createdAt,
    double? distanceMiles,
    double? durationMinutes,
    double? fareUsd,
    List<LocationModel>? routePoints,
    List<RouteStepModel>? routeSteps,
    LocationModel? originLocation,
    LocationModel? destinationLocation,
  }) {
    return TripModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      driverIntercomId: identical(driverIntercomId, _tripModelUnset)
          ? this.driverIntercomId
          : driverIntercomId as String?,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      distanceMiles: distanceMiles ?? this.distanceMiles,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      fareUsd: fareUsd ?? this.fareUsd,
      routePoints: routePoints ?? this.routePoints,
      routeSteps: routeSteps ?? this.routeSteps,
      originLocation: originLocation ?? this.originLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "driverId": driverId,
    "driverIntercomId": driverIntercomId,
    "origin": origin,
    "destination": destination,
    "status": status,
    "createdAt": createdAt.toIso8601String(),
    "distanceMiles": distanceMiles,
    "durationMinutes": durationMinutes,
    "fareUsd": fareUsd,
    "routePoints": routePoints.map((p) => p.toJson()).toList(),
    "routeSteps": routeSteps.map((p) => p.toJson()).toList(),
    "originLocation": originLocation?.toJson(),
    "destinationLocation": destinationLocation?.toJson(),
  };

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json["id"].toString(),
      driverId: json["driverId"].toString(),
      driverIntercomId: json["driverIntercomId"]?.toString(),
      origin: json["origin"].toString(),
      destination: json["destination"].toString(),
      status: json["status"]?.toString() ?? "assigned",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
      distanceMiles: (json["distanceMiles"] as num?)?.toDouble() ?? 0,
      durationMinutes: (json["durationMinutes"] as num?)?.toDouble() ?? 0,
      fareUsd: (json["fareUsd"] as num?)?.toDouble() ?? 0,
      routePoints:
          (json["routePoints"] as List?)
              ?.whereType<Map>()
              .map((p) => LocationModel.fromJson(p.cast<String, dynamic>()))
              .toList() ??
          const <LocationModel>[],
      routeSteps:
          (json["routeSteps"] as List?)
              ?.whereType<Map>()
              .map((p) => RouteStepModel.fromJson(p.cast<String, dynamic>()))
              .toList() ??
          const <RouteStepModel>[],
      originLocation: (json["originLocation"] is Map)
          ? LocationModel.fromJson(
              (json["originLocation"] as Map).cast<String, dynamic>(),
            )
          : null,
      destinationLocation: (json["destinationLocation"] is Map)
          ? LocationModel.fromJson(
              (json["destinationLocation"] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

const Object _tripModelUnset = Object();
