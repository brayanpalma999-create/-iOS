import "package:flutter/material.dart";

import "../models/location_model.dart";
import "../models/trip_model.dart";
import "../services/socket_service.dart";
import "../services/trip_service.dart";

class TripProvider extends ChangeNotifier {
  TripProvider({
    required SocketService socketService,
    required TripService tripService,
  }) : _socketService = socketService,
       _tripService = tripService {
    _bindSocketListeners();
  }

  final SocketService _socketService;
  final TripService _tripService;
  bool _listenersBound = false;

  List<TripModel> get trips => _tripService.trips;

  TripModel assignTrip({
    required String driverId,
    required String origin,
    required String destination,
    double distanceMiles = 0,
    double durationMinutes = 0,
    double fareUsd = 0,
    List<LocationModel> routePoints = const <LocationModel>[],
    LocationModel? originLocation,
    LocationModel? destinationLocation,
  }) {
    final trip = _tripService.createTrip(
      driverId: driverId,
      origin: origin,
      destination: destination,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      fareUsd: fareUsd,
      routePoints: routePoints,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    );
    final payload = trip.toJson();
    payload["toDriverId"] = driverId;
    payload["targetId"] = driverId;
    _socketService.emit("assign:trip", payload);
    return trip;
  }

  void setTripStatus({required String tripId, required String status}) {
    _tripService.updateStatus(tripId, status);
    final trip = _tripService.byId(tripId);
    _socketService.emit("trip:$status", {
      "tripId": tripId,
      "id": tripId,
      "status": status,
      if (trip != null) "driverId": trip.driverId,
    });
    notifyListeners();
  }

  TripModel? latestForDriver(String driverId) =>
      _tripService.latestForDriver(driverId);

  TripModel? latestActiveForDriver(String driverId) =>
      _tripService.latestActiveForDriver(driverId);

  TripModel? byId(String id) => _tripService.byId(id);

  int totalTrips({String? driverId}) =>
      _tripService.totalTrips(driverId: driverId);

  int totalActiveTrips({String? driverId}) =>
      _tripService.totalActiveTrips(driverId: driverId);

  double estimatedRevenue({String? driverId}) =>
      _tripService.estimatedRevenue(driverId: driverId);

  double confirmedRevenue({String? driverId}) =>
      _tripService.confirmedRevenue(driverId: driverId);

  int completedTrips({String? driverId}) =>
      _tripService.completedTrips(driverId: driverId);

  int rejectedTrips({String? driverId}) =>
      _tripService.rejectedTrips(driverId: driverId);

  double acceptanceRate({String? driverId}) =>
      _tripService.acceptanceRate(driverId: driverId);

  double averageFare({String? driverId}) =>
      _tripService.averageFare(driverId: driverId);

  double averageDistanceMiles({String? driverId}) =>
      _tripService.averageDistanceMiles(driverId: driverId);

  void clearAll() {
    _tripService.clear();
    notifyListeners();
  }

  void ingestAssignedTrip(dynamic payload) {
    final map = _asStringMap(payload);
    if (map == null) return;
    final normalized = _normalizeTripMap(map);
    final tripId = _stringValue(normalized["id"] ?? normalized["tripId"]);
    final driverId = _stringValue(
      normalized["driverId"] ??
          normalized["toDriverId"] ??
          normalized["targetId"],
    );
    if (tripId == null || driverId == null) return;

    normalized["id"] = tripId;
    normalized["driverId"] = driverId;
    normalized["status"] =
        (normalized["status"]?.toString().trim().isEmpty ?? true)
        ? "assigned"
        : normalized["status"];
    normalized["createdAt"] =
        normalized["createdAt"]?.toString() ?? DateTime.now().toIso8601String();
    final routePoints = normalized["routePoints"];
    final missingPath = routePoints is! List || routePoints.isEmpty;
    if (missingPath &&
        normalized["originLocation"] is Map &&
        normalized["destinationLocation"] is Map) {
      normalized["routePoints"] = [
        normalized["originLocation"],
        normalized["destinationLocation"],
      ];
    }

    final trip = TripModel.fromJson(normalized);
    _tripService.upsertTrip(trip);
    notifyListeners();
  }

  void _bindSocketListeners() {
    if (_listenersBound) return;
    _listenersBound = true;

    _socketService.on("trip:assigned", (payload) {
      ingestAssignedTrip(payload);
    });
    _socketService.on("assign:trip", (payload) {
      ingestAssignedTrip(payload);
    });
    _socketService.on("trip:accepted", (payload) {
      final map = _asStringMap(payload);
      if (map == null) return;
      final id = _stringValue(map["tripId"] ?? map["id"]);
      if (id == null || id.isEmpty) return;
      _tripService.updateStatus(id, "accepted");
      notifyListeners();
    });
    _socketService.on("trip:rejected", (payload) {
      final map = _asStringMap(payload);
      if (map == null) return;
      final id = _stringValue(map["tripId"] ?? map["id"]);
      if (id == null || id.isEmpty) return;
      _tripService.updateStatus(id, "rejected");
      notifyListeners();
    });
    _socketService.on("trip:update", (payload) {
      ingestAssignedTrip(payload);
    });
    _socketService.on("trip:completed", (payload) {
      final map = _asStringMap(payload);
      if (map == null) return;
      final id = _stringValue(map["tripId"] ?? map["id"]);
      if (id == null || id.isEmpty) return;
      _tripService.updateStatus(id, "completed");
      notifyListeners();
    });
  }

  Map<String, dynamic>? _asStringMap(dynamic payload) {
    if (payload is Map) {
      final map = <String, dynamic>{};
      for (final entry in payload.entries) {
        map[entry.key.toString()] = entry.value;
      }
      return map;
    }
    if (payload is List && payload.isNotEmpty) {
      return _asStringMap(payload.first);
    }
    return null;
  }

  Map<String, dynamic> _normalizeTripMap(Map<String, dynamic> payload) {
    final nested = payload["trip"];
    if (nested is! Map) return payload;

    final merged = <String, dynamic>{};
    for (final entry in nested.entries) {
      merged[entry.key.toString()] = entry.value;
    }
    for (final entry in payload.entries) {
      final existing = merged[entry.key];
      final emptyExisting =
          existing == null || existing.toString().trim().isEmpty;
      if (!merged.containsKey(entry.key) || emptyExisting) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
