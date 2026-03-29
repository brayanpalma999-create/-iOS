import "dart:async";

import "package:flutter/material.dart";

import "../models/driver_model.dart";
import "../models/location_model.dart";
import "../services/location_service.dart";
import "../services/socket_service.dart";
import "trip_provider.dart";

class DriverProvider extends ChangeNotifier {
  DriverProvider({
    required SocketService socketService,
    required LocationService locationService,
    required TripProvider tripProvider,
  }) : _socketService = socketService,
       _locationService = locationService,
       _tripProvider = tripProvider {
    _bindSocketListeners();
  }

  final SocketService _socketService;
  final LocationService _locationService;
  final TripProvider _tripProvider;

  DriverModel? _self;
  final List<DriverModel> _drivers = <DriverModel>[];
  final Map<String, List<LocationModel>> _pathByDriver =
      <String, List<LocationModel>>{};
  StreamSubscription<bool>? _connectionSubscription;
  bool _listenersBound = false;
  String? _lastRegistrationKey;
  String? _sessionRole;
  String? _sessionName;

  DriverModel? get self => _self;
  List<DriverModel> get drivers => List.unmodifiable(_drivers);
  List<LocationModel> pathForDriver(String driverId) =>
      List.unmodifiable(_pathByDriver[driverId] ?? <LocationModel>[]);

  void connectDriver({required String id, required String name}) {
    _self = DriverModel(
      id: id,
      name: name,
      location: LocationModel(latitude: 19.4326, longitude: -99.1332),
      status: "Disponible (Visible)",
    );
    _upsertDriver(_self!);
    _recordPath(_self!.id, _self!.location);
    _sessionRole = "driver";
    _sessionName = _self!.name;

    _socketService.connect("driver:connect", _self!.toJson());
    _registerSession(role: "driver", name: _self!.name);
    _socketService.emit("drivers:request", {});
    _startLocationTracking();
    notifyListeners();
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
    final incoming = <DriverModel>[];
    final incomingIds = <String>{};

    for (final item in payload) {
      if (item is! Map) continue;
      final id = item["id"]?.toString();
      if (id == null || id.isEmpty) continue;
      final name = item["name"]?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final status = item["status"]?.toString() ?? "Disponible";
      final tripId = item["currentTripId"]?.toString();
      final location = _locationFromPayload(item["location"], id);

      final existing = existingById[id];
      DriverModel next;
      if (_self != null &&
          (id == _self!.id || id == (_socketService.socketId ?? ""))) {
        _self = _self!.copyWith(
          id: id,
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
          status: status,
          currentTripId: tripId,
          location: location,
          isOnline: true,
        );
      } else {
        next = DriverModel(
          id: id,
          name: name,
          location: location,
          status: status,
          currentTripId: tripId,
          isOnline: true,
        );
      }

      incoming.add(next);
      incomingIds.add(id);
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
    final status = payload["status"]?.toString();

    final index = _drivers.indexWhere((d) => d.id == driverId);
    final base = index >= 0
        ? _drivers[index]
        : DriverModel(
            id: driverId,
            name: payload["name"]?.toString() ?? "Driver",
            location: _fallbackLocation(driverId),
            status: "Disponible",
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
      status: status ?? base.status,
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
      map["driverId"] ?? map["toDriverId"] ?? map["targetId"],
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
    final nextStatus = switch (tripStatus) {
      "accepted" => "En camino",
      "rejected" => "Disponible",
      _ => "Asignado",
    };
    final nextTripId = tripStatus == "rejected" ? null : tripId;

    _self = _self?.copyWith(status: nextStatus, currentTripId: nextTripId);
    if (_self != null) {
      _upsertDriver(_self!);
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
        "name": _self!.name,
        "status": _self!.status,
        ...location.toJson(),
      });
      _recordPath(_self!.id, location);
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

  LocationModel _fallbackLocation(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    final latOffset = ((hash % 120) - 60) * 0.00003;
    final lonOffset = (((hash ~/ 2) % 120) - 60) * 0.00003;
    final base = _self?.location;
    if (base != null) {
      return LocationModel(
        latitude: base.latitude + latOffset,
        longitude: base.longitude + lonOffset,
      );
    }
    return LocationModel(
      latitude: 19.4326 + latOffset,
      longitude: -99.1332 + lonOffset,
    );
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
      status: accepted ? "En camino" : "Disponible",
      currentTripId: accepted ? tripId : null,
    );
    if (_self != null) {
      _upsertDriver(_self!);
      _socketService.emit("driver:location:update", {
        "driverId": _self!.id,
        "name": _self!.name,
        "status": _self!.status,
        ..._self!.location.toJson(),
      });
    }
    notifyListeners();
  }

  void setOperationalStatus(String status) {
    if (_self == null) return;
    _self = _self!.copyWith(status: status);
    _upsertDriver(_self!);
    _socketService.emit("driver:location:update", {
      "driverId": _self!.id,
      "name": _self!.name,
      "status": status,
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

  void clearAssignedTrip() {
    if (_self == null) return;
    final status = _self!.status == "En camino" ? "Disponible" : _self!.status;
    _self = _self!.copyWith(currentTripId: null, status: status);
    _upsertDriver(_self!);
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _locationService.stop();
    _socketService.disconnect();
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
    return _fallbackLocation(seed);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
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
    final selfId = _self?.id;
    final socketId = _socketService.socketId;
    return driverId == selfId || driverId == socketId;
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
