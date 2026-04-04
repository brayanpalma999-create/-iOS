import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/location_model.dart";
import "../models/trip_model.dart";
import "../services/socket_service.dart";
import "../services/trip_service.dart";
import "../utils/constants.dart";

class TripProvider extends ChangeNotifier {
  TripProvider({
    required SocketService socketService,
    required TripService tripService,
  }) : _socketService = socketService,
       _tripService = tripService {
    _bindSocketListeners();
    unawaited(_initialize());
  }

  final SocketService _socketService;
  final TripService _tripService;
  bool _listenersBound = false;
  Future<void>? _initializeFuture;
  static const String _tripCacheKey = "atob_trip_cache_v1";

  List<TripModel> get trips => _tripService.trips;

  Future<void> _initialize() async {
    await (_initializeFuture ??= _hydrateFromLocalCache());
    await refreshFromServer();
  }

  TripModel assignTrip({
    required String driverId,
    String? driverIntercomId,
    required String origin,
    required String destination,
    double distanceMiles = 0,
    double durationMinutes = 0,
    double fareUsd = 0,
    List<LocationModel> routePoints = const <LocationModel>[],
    List<RouteStepModel> routeSteps = const <RouteStepModel>[],
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
      routeSteps: routeSteps,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    );
    _tripService.upsertTrip(trip);
    final payload = trip.toJson();
    payload["toDriverId"] = driverId;
    payload["targetId"] = driverId;
    payload["driverIntercomId"] = driverIntercomId ?? driverId;
    _socketService.emit("assign:trip", payload);
    unawaited(_persistLocalTrips());
    notifyListeners();
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
    unawaited(_persistLocalTrips());
    notifyListeners();
  }

  void updateTripNavigation({
    required String tripId,
    String? status,
    double? distanceMiles,
    double? durationMinutes,
    double? fareUsd,
    List<LocationModel>? routePoints,
    List<RouteStepModel>? routeSteps,
    LocationModel? originLocation,
    LocationModel? destinationLocation,
  }) {
    _tripService.updateTrip(
      tripId,
      status: status,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      fareUsd: fareUsd,
      routePoints: routePoints,
      routeSteps: routeSteps,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    );
    final trip = _tripService.byId(tripId);
    if (trip != null) {
      _socketService.emit("trip:update", trip.toJson());
    }
    unawaited(_persistLocalTrips());
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

  double serviceFeeRevenue({String? driverId, bool confirmedOnly = false}) =>
      _tripService.serviceFeeRevenue(
        driverId: driverId,
        confirmedOnly: confirmedOnly,
      );

  double driverNetRevenue({String? driverId, bool confirmedOnly = false}) =>
      _tripService.driverNetRevenue(
        driverId: driverId,
        confirmedOnly: confirmedOnly,
      );

  double serviceFeeForTrip(TripModel trip) => _tripService.serviceFeeForTrip(trip);

  double driverNetForTrip(TripModel trip) => _tripService.driverNetForTrip(trip);

  double averageDriverNet({String? driverId}) =>
      _tripService.averageDriverNet(driverId: driverId);

  bool countsTowardConfirmedEarnings(TripModel trip) =>
      _tripService.countsTowardConfirmedEarnings(trip);

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
    unawaited(_persistLocalTrips());
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
          normalized["targetId"] ??
          normalized["driverIntercomId"],
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
    final trip = TripModel.fromJson(normalized);
    _tripService.upsertTrip(trip);
    unawaited(_persistLocalTrips());
    notifyListeners();
  }

  Future<void> refreshFromServer({String? driverId}) async {
    final response = await _sendJsonRequest(
      method: "GET",
      path: "/trips/history",
      queryParameters: {
        if ((driverId ?? "").trim().isNotEmpty) "driverId": driverId!.trim(),
        "limit": "200",
      },
    );
    if (response == null || response["ok"] != true) return;
    final rawTrips = response["trips"];
    if (rawTrips is! List) return;
    final loaded = rawTrips
        .whereType<Map>()
        .map((item) => TripModel.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    if (loaded.isEmpty && _tripService.trips.isNotEmpty) {
      return;
    }
    _tripService.replaceAll(loaded);
    await _persistLocalTrips();
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
      unawaited(_persistLocalTrips());
      notifyListeners();
    });
    _socketService.on("trip:picked_up", (payload) {
      final map = _asStringMap(payload);
      if (map == null) return;
      final id = _stringValue(map["tripId"] ?? map["id"]);
      if (id == null || id.isEmpty) return;
      _tripService.updateStatus(id, "picked_up");
      unawaited(_persistLocalTrips());
      notifyListeners();
    });
    _socketService.on("trip:rejected", (payload) {
      final map = _asStringMap(payload);
      if (map == null) return;
      final id = _stringValue(map["tripId"] ?? map["id"]);
      if (id == null || id.isEmpty) return;
      _tripService.updateStatus(id, "rejected");
      unawaited(_persistLocalTrips());
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
      unawaited(_persistLocalTrips());
      notifyListeners();
    });
  }

  Future<void> _hydrateFromLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tripCacheKey);
    if ((raw ?? "").trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw!);
      if (decoded is! List) return;
      final cached = decoded
          .whereType<Map>()
          .map((item) => TripModel.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      if (cached.isEmpty) return;
      _tripService.replaceAll(cached);
      notifyListeners();
    } catch (_) {
      // Ignore malformed local cache.
    }
  }

  Future<void> _persistLocalTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      _tripService.trips.map((trip) => trip.toJson()).toList(growable: false),
    );
    await prefs.setString(_tripCacheKey, payload);
  }

  Future<Map<String, dynamic>?> _sendJsonRequest({
    required String method,
    required String path,
    Map<String, String>? queryParameters,
  }) async {
    final client = HttpClient();
    try {
      var uri = Uri.parse("${AppConstants.socketUrl}$path");
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, "application/json");
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
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
