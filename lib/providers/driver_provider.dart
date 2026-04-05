import "dart:async";

import "package:flutter/material.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";

import "../models/driver_model.dart";
import "../models/location_model.dart";
import "../models/trip_model.dart";
import "../models/user_model.dart";
import "../services/location_service.dart";
import "../services/map_service.dart";
import "../services/route_notification_service.dart";
import "../services/socket_service.dart";
import "trip_provider.dart";

class DriverProvider extends ChangeNotifier {
  DriverProvider({
    required SocketService socketService,
    required LocationService locationService,
    required MapService mapService,
    required TripProvider tripProvider,
    required RouteNotificationService routeNotificationService,
  }) : _socketService = socketService,
       _locationService = locationService,
       _mapService = mapService,
       _tripProvider = tripProvider,
       _routeNotificationService = routeNotificationService {
    _bindSocketListeners();
    _bindRouteNotificationActions();
    unawaited(_consumePendingRouteAction());
  }

  final SocketService _socketService;
  final LocationService _locationService;
  final MapService _mapService;
  final TripProvider _tripProvider;
  final RouteNotificationService _routeNotificationService;

  DriverModel? _self;
  final List<DriverModel> _drivers = <DriverModel>[];
  final Map<String, List<LocationModel>> _pathByDriver =
      <String, List<LocationModel>>{};
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<RouteNotificationAction>? _routeActionSubscription;
  bool _listenersBound = false;
  String? _lastRegistrationKey;
  String? _sessionRole;
  String? _sessionName;
  DateTime? _lastNavigationRefreshAt;
  bool _navigationRefreshInFlight = false;

  DriverModel? get self => _self;
  List<DriverModel> get drivers => List.unmodifiable(_drivers);
  List<LocationModel> pathForDriver(String driverId) =>
      List.unmodifiable(_pathByDriver[driverId] ?? <LocationModel>[]);

  Future<void> connectDriver({
    required String id,
    required String name,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
    String? avatarPath,
    String? languageCode,
    String? mapThemeMode,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    String? vehicleYear,
  }) async {
    final initialLocation = await _resolveInitialLocation();
    final profile = _buildDriverProfile(
      id: id,
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      address: address,
      governmentId: governmentId,
    );
    final safeInitialLocation = initialLocation ?? _emptyLocation();
    final initialStatus = initialLocation == null
        ? "Ubicacion pendiente"
        : "No disponible (Invisible)";
    _self = DriverModel(
      id: id,
      intercomId: id,
      name: name,
      legalName: profile.legalName,
      email: profile.email,
      phoneNumber: profile.phoneNumber,
      address: profile.address,
      governmentId: profile.governmentId,
      avatarPath: avatarPath,
      languageCode: languageCode ?? "es",
      mapThemeMode: mapThemeMode ?? "flow",
      vehicleMake: _cleanValue(vehicleMake),
      vehicleModel: _cleanValue(vehicleModel),
      vehicleColor: _cleanValue(vehicleColor),
      vehiclePlate: _cleanValue(vehiclePlate),
      vehicleYear: _cleanValue(vehicleYear),
      location: safeInitialLocation,
      status: initialStatus,
    );
    _upsertDriver(_self!);
    if (initialLocation != null) {
      _recordPath(_self!.id, _self!.location);
    }
    _sessionRole = "driver";
    _sessionName = _self!.name;

    _socketService.connect("driver:connect", _self!.toJson());
    _registerSession(role: "driver", name: _self!.name);
    _socketService.emit("drivers:request", {});
    _startLocationTracking();
    unawaited(_restoreCurrentTripFromServer());
    notifyListeners();
  }

  Future<LocationModel?> _resolveInitialLocation() async {
    final permissionOk = await _locationService.requestPermission();
    if (!permissionOk) return null;

    try {
      return await _locationService.current().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {
      // Fall through to last known location.
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) return null;
      return LocationModel(
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
        speed: lastKnown.speed,
        timestamp: lastKnown.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  _DriverProfile _buildDriverProfile({
    required String id,
    required String name,
    String? email,
    String? phoneNumber,
    String? address,
    String? governmentId,
  }) {
    final shortId = id.length <= 6 ? id : id.substring(id.length - 6);
    final slug = name.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "");
    return _DriverProfile(
      legalName: name,
      email: _cleanValue(email) ?? "${slug.isEmpty ? 'driver$shortId' : slug}@atob.app",
      phoneNumber:
          _cleanValue(phoneNumber) ??
          "+1 804 555 ${shortId.padLeft(4, "0").substring(2)}",
      address: _cleanValue(address) ?? "Virginia driver zone",
      governmentId: _cleanValue(governmentId) ?? "DRV-$shortId",
    );
  }

  void attachAdminSession({required String name}) {
    _sessionRole = "admin";
    _sessionName = name;
    _registerSession(role: "admin", name: name);
    _socketService.emit("drivers:request", {});
  }

  void _bindSocketListeners() {
    if (_listenersBound) return;
    _listenersBound = true;

    _socketService.on("drivers:list", _onDriversList);
    _socketService.on("driver:location:update", _onDriverLocationUpdate);
    _socketService.on("trip:assigned", _onAssignedTrip);
    _socketService.on("assign:trip", _onAssignedTrip);
    _socketService.on("trip:update", _onAssignedTrip);

    _connectionSubscription = _socketService.connectionState.listen((
      connected,
    ) {
      if (!connected) {
        _lastRegistrationKey = null;
        return;
      }
      _syncSelfWithSocketId();
      if (_sessionRole != null && _sessionName != null) {
        _registerSession(role: _sessionRole!, name: _sessionName!);
      }
      _socketService.emit("drivers:request", {});
      unawaited(_restoreCurrentTripFromServer());
    });
  }

  void _registerSession({required String role, required String name}) {
    if (!_socketService.isConnected) return;
    final socketId = _socketService.socketId ?? "";
    final key = "$socketId|$role|$name";
    if (_lastRegistrationKey == key) return;
    _lastRegistrationKey = key;
    _socketService.emit("register", {"role": role, "name": name});
  }

  void _syncSelfWithSocketId() {
    final socketId = _socketService.socketId;
    if (_self == null || socketId == null || socketId.isEmpty) return;
    if (_self!.id == socketId) return;

    final previousId = _self!.id;
    final previousPath = _pathByDriver.remove(previousId);
    _self = _self!.copyWith(id: socketId);
    if (previousPath != null) {
      _pathByDriver[socketId] = previousPath;
    }
    _upsertDriver(_self!);
    notifyListeners();
  }

  void _onDriversList(dynamic payload) {
    if (payload is! List) return;

    final existingById = <String, DriverModel>{
      for (final driver in _drivers) driver.id: driver,
    };
    final existingByStableKey = <String, DriverModel>{
      for (final driver in _drivers) _stableDriverKey(driver): driver,
    };
    final incoming = <DriverModel>[];
    final incomingIds = <String>{};
    final incomingStableKeys = <String>{};

    for (final item in payload) {
      if (item is! Map) continue;
      final id = item["id"]?.toString();
      if (id == null || id.isEmpty) continue;
      final itemStableKey = _stableDriverKeyFromPayload(item, fallbackId: id);
      if (incomingStableKeys.contains(itemStableKey)) {
        continue;
      }
      final name = item["name"]?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final status = _normalizeOperationalStatus(
        item["status"]?.toString(),
        fallback: existingById[id]?.status ?? "No disponible (Invisible)",
      );
      final tripId = _stringValue(item["currentTripId"]);
      final location = _locationFromPayload(item["location"], id);

      final existing =
          existingById[id] ?? existingByStableKey[itemStableKey];
      DriverModel next;
      if (_self != null &&
          (id == _self!.id ||
              id == (_socketService.socketId ?? "") ||
              itemStableKey == _stableDriverKey(_self!))) {
        _self = _self!.copyWith(
          id: id,
          intercomId:
              item["intercomId"]?.toString() ?? _self!.intercomId ?? _self!.id,
          name: name,
          status: status,
          currentTripId: tripId,
          location: location,
          isOnline: true,
        );
        next = _self!;
      } else if (existing != null) {
        next = existing.copyWith(
          name: name,
          intercomId:
              item["intercomId"]?.toString() ?? existing.intercomId ?? id,
          status: status,
          currentTripId: tripId,
          location: location,
          isOnline: true,
        );
      } else {
        next = DriverModel(
          id: id,
          intercomId: item["intercomId"]?.toString() ?? id,
          name: name,
          legalName: name,
          email: item["email"]?.toString() ?? "$id@atob.app",
          phoneNumber: item["phoneNumber"]?.toString() ?? "+1 804 555 0000",
          address: item["address"]?.toString() ?? "Operational area",
          governmentId: item["governmentId"]?.toString() ?? "DRV-$id",
          vehicleMake: _stringValue(item["vehicleMake"]),
          vehicleModel: _stringValue(item["vehicleModel"]),
          vehicleColor: _stringValue(item["vehicleColor"]),
          vehiclePlate: _stringValue(item["vehiclePlate"]),
          vehicleYear: _stringValue(item["vehicleYear"]),
          location: location,
          status: status,
          currentTripId: tripId,
          isOnline: true,
        );
      }

      incoming.add(next);
      incomingIds.add(id);
      incomingStableKeys.add(itemStableKey);
      _pathByDriver.putIfAbsent(id, () => <LocationModel>[next.location]);
    }

    if (_self != null && !incomingIds.contains(_self!.id)) {
      incoming.add(_self!.copyWith(isOnline: true));
      incomingIds.add(_self!.id);
      _pathByDriver.putIfAbsent(
        _self!.id,
        () => <LocationModel>[_self!.location],
      );
    }

    _drivers
      ..clear()
      ..addAll(incoming);

    _pathByDriver.removeWhere((id, _) => !incomingIds.contains(id));
    notifyListeners();
  }

  void _onDriverLocationUpdate(dynamic payload) {
    if (payload is! Map) return;
    final driverId = payload["driverId"]?.toString();
    if (driverId == null || driverId.isEmpty) return;

    final latitude = (payload["latitude"] as num?)?.toDouble();
    final longitude = (payload["longitude"] as num?)?.toDouble();
    final index = _drivers.indexWhere((d) => d.id == driverId);
    final status = _normalizeOperationalStatus(
      payload["status"]?.toString(),
      fallback: index >= 0 ? _drivers[index].status : "No disponible (Invisible)",
    );
    final base = index >= 0
        ? _drivers[index]
        : DriverModel(
            id: driverId,
            intercomId: payload["intercomId"]?.toString() ?? driverId,
            name: payload["name"]?.toString() ?? "Driver",
            legalName: payload["name"]?.toString() ?? "Driver",
            email: payload["email"]?.toString() ?? "$driverId@atob.app",
            phoneNumber:
                payload["phoneNumber"]?.toString() ?? "+1 804 555 0000",
            address: payload["address"]?.toString() ?? "Operational area",
            governmentId:
                payload["governmentId"]?.toString() ?? "DRV-$driverId",
            vehicleMake: _stringValue(payload["vehicleMake"]),
            vehicleModel: _stringValue(payload["vehicleModel"]),
            vehicleColor: _stringValue(payload["vehicleColor"]),
            vehiclePlate: _stringValue(payload["vehiclePlate"]),
            vehicleYear: _stringValue(payload["vehicleYear"]),
            location: _emptyLocation(),
            status: "No disponible (Invisible)",
            isOnline: true,
          );
    final nextLocation = (latitude != null && longitude != null)
        ? LocationModel(
            latitude: latitude,
            longitude: longitude,
            speed: (payload["speed"] as num?)?.toDouble() ?? 0,
            timestamp: payload["timestamp"] == null
                ? null
                : DateTime.tryParse(payload["timestamp"].toString()),
          )
        : base.location;
    final next = base.copyWith(
      location: nextLocation,
      intercomId: payload["intercomId"]?.toString() ?? base.intercomId,
      status: status,
      isOnline: true,
    );

    _upsertDriver(next);
    _recordPath(next.id, next.location);
    if (_self != null && next.id == _self!.id) {
      _self = _self!.copyWith(location: next.location, status: next.status);
    }
    notifyListeners();
  }

  void _onAssignedTrip(dynamic payload) {
    final map = _asStringMap(payload);
    if (map == null) return;
    _tripProvider.ingestAssignedTrip(map);

    final targetDriverId = _stringValue(
      map["driverId"] ??
          map["toDriverId"] ??
          map["targetId"] ??
          map["driverIntercomId"],
    );
    if (!_matchesSelfDriverId(targetDriverId)) return;

    if (_self != null &&
        targetDriverId != null &&
        targetDriverId.isNotEmpty &&
        _self!.id != targetDriverId) {
      final oldPath = _pathByDriver.remove(_self!.id);
      _self = _self!.copyWith(id: targetDriverId);
      if (oldPath != null) {
        _pathByDriver[targetDriverId] = oldPath;
      }
    }

    final tripId = _stringValue(map["id"] ?? map["tripId"]);
    final tripStatus = _stringValue(map["status"])?.toLowerCase();
    final nextTripId =
        (tripStatus == "rejected" ||
                tripStatus == "completed" ||
                tripStatus == "cancelled")
        ? null
        : tripId;

    _self = _self?.copyWith(currentTripId: nextTripId);
    if (_self != null) {
      _upsertDriver(_self!);
    }
    if (tripId != null &&
        tripId.isNotEmpty &&
        (tripStatus == null || tripStatus == "assigned")) {
      final trip = _tripProvider.byId(tripId);
      if (trip != null) {
        unawaited(_routeNotificationService.showTripAssignedNotification(trip));
      }
    }
    notifyListeners();
  }

  Future<void> startAssignedTrip(String tripId) async {
    _tripProvider.setTripStatus(tripId: tripId, status: "accepted");
    _self = _self?.copyWith(currentTripId: tripId);
    if (_self != null) {
      _recordPath(_self!.id, _self!.location, reset: true);
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "intercomId": _self!.intercomId,
        "name": _self!.name,
        "status": _self!.status,
        "currentTripId": tripId,
        ..._self!.location.toJson(),
      });
    }
    await _refreshNavigationRouteForTrip(tripId);
    notifyListeners();
  }

  Future<void> _restoreCurrentTripFromServer() async {
    final self = _self;
    if (self == null) return;
    final stableDriverId = (self.intercomId ?? self.id).trim();
    if (stableDriverId.isEmpty) return;
    await _tripProvider.refreshFromServer(driverId: stableDriverId);
    final activeTrip = _tripProvider.latestActiveForDriver(stableDriverId);
    if (activeTrip == null) {
      if (self.currentTripId == null) return;
      _self = self.copyWith(currentTripId: null);
      _upsertDriver(_self!);
      notifyListeners();
      return;
    }
    _self = self.copyWith(currentTripId: activeTrip.id);
    _upsertDriver(_self!);
    _socketService.emit("driver:location:update", {
      "driverId": _self!.id,
      "intercomId": _self!.intercomId,
      "name": _self!.name,
      "status": _self!.status,
      "currentTripId": activeTrip.id,
      ..._self!.location.toJson(),
    });
    notifyListeners();
  }

  Future<void> markPassengerPickedUp(String tripId) async {
    _tripProvider.setTripStatus(tripId: tripId, status: "picked_up");
    _self = _self?.copyWith(currentTripId: tripId);
    if (_self != null) {
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "intercomId": _self!.intercomId,
        "name": _self!.name,
        "status": _self!.status,
        "currentTripId": tripId,
        ..._self!.location.toJson(),
      });
    }
    await _refreshNavigationRouteForTrip(tripId);
    notifyListeners();
  }

  void completeCurrentTrip(String tripId) {
    _tripProvider.setTripStatus(tripId: tripId, status: "completed");
    _lastNavigationRefreshAt = null;
    _navigationRefreshInFlight = false;
    _self = _self?.copyWith(currentTripId: null);
    if (_self != null) {
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "intercomId": _self!.intercomId,
        "name": _self!.name,
        "status": _self!.status,
        "currentTripId": null,
        ..._self!.location.toJson(),
      });
    }
    notifyListeners();
  }

  Future<void> _startLocationTracking() async {
    await _locationService.start((location) {
      if (_self == null) return;
      _self = _self!.copyWith(location: location, status: _self!.status);
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "intercomId": _self!.intercomId,
        "name": _self!.name,
        "status": _self!.status,
        ...location.toJson(),
      });
      _recordPath(_self!.id, location);
      unawaited(_maybeRefreshNavigationRoute(location));
      notifyListeners();
    });
  }

  void _upsertDriver(DriverModel driver) {
    final index = _drivers.indexWhere((d) => d.id == driver.id);
    if (index >= 0) {
      _drivers[index] = driver;
      return;
    }
    _drivers.add(driver);
  }

  LocationModel _emptyLocation() {
    return LocationModel(latitude: 0, longitude: 0, speed: 0);
  }

  void _recordPath(
    String driverId,
    LocationModel location, {
    bool reset = false,
  }) {
    final path = reset
        ? <LocationModel>[]
        : (_pathByDriver[driverId] ?? <LocationModel>[]);
    path.add(location);
    if (path.length > 80) {
      path.removeAt(0);
    }
    _pathByDriver[driverId] = path;
  }

  void setTripDecision(String tripId, bool accepted) {
    final status = accepted ? "accepted" : "rejected";
    _tripProvider.setTripStatus(tripId: tripId, status: status);
    _self = _self?.copyWith(
      currentTripId: accepted ? tripId : null,
    );
    if (_self != null) {
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "intercomId": _self!.intercomId,
        "name": _self!.name,
        "status": _self!.status,
        ..._self!.location.toJson(),
      });
    }
    notifyListeners();
  }

  void setOperationalStatus(String status) {
    if (_self == null) return;
    final nextStatus = _normalizeOperationalStatus(
      status,
      fallback: _self!.status,
    );
    _self = _self!.copyWith(status: nextStatus);
    _upsertDriver(_self!);
    _socketService.emit("driver:location:update", {
      "driverId": _self!.id,
      "intercomId": _self!.intercomId,
      "name": _self!.name,
      "status": nextStatus,
      ..._self!.location.toJson(),
    });
    notifyListeners();
  }

  void updateDisplayName(String name) {
    final normalized = name.trim();
    if (_self == null || normalized.isEmpty) return;
    _self = _self!.copyWith(name: normalized);
    _sessionName = normalized;
    _upsertDriver(_self!);
    _registerSession(role: "driver", name: normalized);
    notifyListeners();
  }

  void syncProfileFromUser(UserModel user) {
    if (_self == null) return;
    final next = _self!.copyWith(
      name: _cleanValue(user.name) ?? _self!.name,
      legalName: _cleanValue(user.legalName) ?? _self!.legalName,
      email: _cleanValue(user.email) ?? _self!.email,
      phoneNumber: _cleanValue(user.phoneNumber) ?? _self!.phoneNumber,
      address: _cleanValue(user.address) ?? _self!.address,
      governmentId: _cleanValue(user.governmentId) ?? _self!.governmentId,
      avatarPath: _cleanValue(user.avatarPath) ?? _self!.avatarPath,
      languageCode: _cleanValue(user.languageCode) ?? _self!.languageCode,
      mapThemeMode: _cleanValue(user.mapThemeMode) ?? _self!.mapThemeMode,
      vehicleMake: _cleanValue(user.vehicleMake),
      vehicleModel: _cleanValue(user.vehicleModel),
      vehicleColor: _cleanValue(user.vehicleColor),
      vehiclePlate: _cleanValue(user.vehiclePlate),
      vehicleYear: _cleanValue(user.vehicleYear),
    );
    _self = next;
    _sessionName = next.name;
    _upsertDriver(next);
    _registerSession(role: "driver", name: next.name);
    _socketService.emit("driver:location:update", {
      "driverId": next.id,
      "intercomId": next.intercomId,
      "name": next.name,
      "status": next.status,
      "email": next.email,
      "phoneNumber": next.phoneNumber,
      "address": next.address,
      "governmentId": next.governmentId,
      "avatarPath": next.avatarPath,
      "vehicleMake": next.vehicleMake,
      "vehicleModel": next.vehicleModel,
      "vehicleColor": next.vehicleColor,
      "vehiclePlate": next.vehiclePlate,
      "vehicleYear": next.vehicleYear,
      ...next.location.toJson(),
    });
    notifyListeners();
  }

  void clearAssignedTrip() {
    if (_self == null) return;
    _self = _self!.copyWith(currentTripId: null);
    _upsertDriver(_self!);
    notifyListeners();
  }

  Future<void> _maybeRefreshNavigationRoute(LocationModel current) async {
    final self = _self;
    final tripId = self?.currentTripId;
    if (self == null || tripId == null) return;
    final trip = _tripProvider.byId(tripId);
    if (trip == null) return;
    if (trip.status != "accepted" && trip.status != "picked_up") return;
    if (_navigationRefreshInFlight) return;

    final now = DateTime.now();
    final last = _lastNavigationRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }

    if (!_shouldRefreshForDeviation(current, trip)) return;
    await _refreshNavigationRouteForTrip(tripId, currentLocation: current);
  }

  bool _shouldRefreshForDeviation(LocationModel current, TripModel trip) {
    final route = trip.routePoints;
    if (route.length < 2) return true;
    final here = LatLng(current.latitude, current.longitude);
    final distance = Distance();
    final routeStart = LatLng(route.first.latitude, route.first.longitude);
    final startMeters = distance.as(LengthUnit.Meter, here, routeStart);
    var closestMeters = double.infinity;
    for (final point in route) {
      final meters = distance.as(
        LengthUnit.Meter,
        here,
        LatLng(point.latitude, point.longitude),
      );
      if (meters < closestMeters) {
        closestMeters = meters;
      }
    }
    return startMeters > 22 || closestMeters > 38;
  }

  Future<void> _refreshNavigationRouteForTrip(
    String tripId, {
    LocationModel? currentLocation,
  }) async {
    final trip = _tripProvider.byId(tripId);
    final self = _self;
    if (trip == null || self == null) return;
    final current = currentLocation ?? self.location;
    if ((current.latitude.abs() <= 0.001 && current.longitude.abs() <= 0.001)) {
      return;
    }

    final destination = trip.destinationLocation;
    if (destination == null) return;
    final routeStops = <LatLng>[
      LatLng(current.latitude, current.longitude),
    ];
    if (trip.status == "accepted") {
      final origin = trip.originLocation;
      if (origin != null) {
        routeStops.add(LatLng(origin.latitude, origin.longitude));
      }
    }
    routeStops.add(LatLng(destination.latitude, destination.longitude));

    _navigationRefreshInFlight = true;
    try {
      final estimate = await _mapService.calculateRouteChain(stops: routeStops);
      if (estimate == null) return;
      _tripProvider.updateTripNavigation(
        tripId: tripId,
        distanceMiles: trip.distanceMiles,
        durationMinutes: estimate.durationMinutes,
        fareUsd: trip.fareUsd,
        routePoints: estimate.path
            .map(
              (point) => LocationModel(
                latitude: point.latitude,
                longitude: point.longitude,
              ),
            )
            .toList(),
        routeSteps: estimate.steps,
      );
      _lastNavigationRefreshAt = DateTime.now();
    } finally {
      _navigationRefreshInFlight = false;
    }
  }

  Future<void> disconnect() async {
    await _locationService.stop();
    _socketService.disconnect();
    _tripProvider.clearAll();
    _lastRegistrationKey = null;
    _sessionRole = null;
    _sessionName = null;
    _self = null;
    _drivers.clear();
    _pathByDriver.clear();
    notifyListeners();
  }

  LocationModel _locationFromPayload(dynamic payload, String seed) {
    if (payload is Map) {
      final lat = (payload["latitude"] as num?)?.toDouble();
      final lng = (payload["longitude"] as num?)?.toDouble();
      if (lat != null && lng != null) {
        return LocationModel(
          latitude: lat,
          longitude: lng,
          speed: (payload["speed"] as num?)?.toDouble() ?? 0,
          timestamp: payload["timestamp"] == null
              ? null
              : DateTime.tryParse(payload["timestamp"].toString()),
        );
      }
    }
    final existing = _drivers.where((d) => d.id == seed).toList();
    if (existing.isNotEmpty) return existing.first.location;
    return _emptyLocation();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _routeActionSubscription?.cancel();
    super.dispose();
  }

  void _bindRouteNotificationActions() {
    _routeActionSubscription ??= _routeNotificationService.actions.listen((
      action,
    ) {
      unawaited(_handleRouteNotificationAction(action));
    });
  }

  Future<void> _consumePendingRouteAction() async {
    final pending = await _routeNotificationService.consumePendingAction();
    if (pending == null) return;
    await _handleRouteNotificationAction(pending);
  }

  Future<void> _handleRouteNotificationAction(
    RouteNotificationAction action,
  ) async {
    if (action.actionId != RouteNotificationService.startRouteActionId) {
      return;
    }
    final trip = _tripProvider.byId(action.tripId);
    if (trip == null) return;
    if (trip.status == "accepted" || trip.status == "picked_up") {
      return;
    }
    await startAssignedTrip(action.tripId);
  }

  Map<String, dynamic>? _asStringMap(dynamic payload) {
    if (payload is Map) {
      final map = <String, dynamic>{};
      for (final entry in payload.entries) {
        map[entry.key.toString()] = entry.value;
      }
      if (map["trip"] is Map) {
        final merged = <String, dynamic>{};
        final nested = map["trip"] as Map;
        for (final entry in nested.entries) {
          merged[entry.key.toString()] = entry.value;
        }
        for (final entry in map.entries) {
          if (!merged.containsKey(entry.key)) {
            merged[entry.key] = entry.value;
          }
        }
        return merged;
      }
      return map;
    }
    if (payload is List && payload.isNotEmpty) {
      return _asStringMap(payload.first);
    }
    return null;
  }

  bool _matchesSelfDriverId(String? driverId) {
    if (driverId == null || driverId.isEmpty) return false;
    final target = driverId.trim();
    final targetLower = target.toLowerCase();
    final selfId = _self?.id.trim();
    final intercomId = _self?.intercomId?.trim();
    final socketId = _socketService.socketId?.trim();
    final selfLower = selfId?.toLowerCase();
    final intercomLower = intercomId?.toLowerCase();
    final socketLower = socketId?.toLowerCase();
    return (selfId != null && (target == selfId || targetLower == selfLower)) ||
        (intercomId != null &&
            (target == intercomId || targetLower == intercomLower)) ||
        (socketId != null &&
            (target == socketId || targetLower == socketLower));
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _cleanValue(String? value) {
    final text = (value ?? "").trim();
    return text.isEmpty ? null : text;
  }

  String _normalizeOperationalStatus(String? raw, {required String fallback}) {
    final value = (raw ?? "").trim();
    if (value.isEmpty) return fallback;
    final lower = value.toLowerCase();
    if (lower.contains("ubicacion pendiente")) {
      return "Ubicacion pendiente";
    }
    if (lower.startsWith("disponible")) {
      return "Disponible (Visible)";
    }
    if (lower.contains("invisible") || lower.contains("no disponible")) {
      return "No disponible (Invisible)";
    }
    return fallback;
  }

  String _stableDriverKey(DriverModel driver) {
    final intercom = (driver.intercomId ?? "").trim().toLowerCase();
    if (intercom.isNotEmpty) return "intercom:$intercom";
    final email = driver.email.trim().toLowerCase();
    if (email.isNotEmpty) return "email:$email";
    return "id:${driver.id.trim().toLowerCase()}";
  }

  String _stableDriverKeyFromPayload(Map payload, {required String fallbackId}) {
    final intercom = payload["intercomId"]?.toString().trim().toLowerCase() ?? "";
    if (intercom.isNotEmpty) return "intercom:$intercom";
    final email = payload["email"]?.toString().trim().toLowerCase() ?? "";
    if (email.isNotEmpty) return "email:$email";
    return "id:${fallbackId.trim().toLowerCase()}";
  }
}

class _DriverProfile {
  const _DriverProfile({
    required this.legalName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.governmentId,
  });

  final String legalName;
  final String email;
  final String phoneNumber;
  final String address;
  final String governmentId;
}
