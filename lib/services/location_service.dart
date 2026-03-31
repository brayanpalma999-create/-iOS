import "dart:async";
import "dart:io";

import "package:geolocator/geolocator.dart";

import "../models/location_model.dart";

class LocationService {
  StreamSubscription<Position>? _subscription;
  Timer? _fallbackPollTimer;
  DateTime? _lastFixAt;
  bool _precisionHintShown = false;
  Future<bool>? _permissionInFlight;

  Future<bool> requestPermission() async {
    final inFlight = _permissionInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _requestPermissionInternal();
    _permissionInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_permissionInFlight, future)) {
        _permissionInFlight = null;
      }
    }
  }

  Future<bool> _requestPermissionInternal() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) return false;

    // If user selected approximate location, guide once to app settings to
    // enable precise mode for better route quality.
    final accuracy = await Geolocator.getLocationAccuracy();
    if (!_precisionHintShown &&
        accuracy == LocationAccuracyStatus.reduced &&
        Platform.isIOS) {
      _precisionHintShown = true;
      try {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: "PreciseNavigation",
        );
      } catch (_) {
        await Geolocator.openAppSettings();
      }
    } else if (!_precisionHintShown &&
        accuracy == LocationAccuracyStatus.reduced &&
        Platform.isAndroid) {
      _precisionHintShown = true;
      await Geolocator.openAppSettings();
    }
    return true;
  }

  Future<LocationModel> current() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: _settings(),
    );
    return LocationModel(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }

  Future<void> start(void Function(LocationModel) onLocation) async {
    final permissionOk = await requestPermission();
    if (!permissionOk) {
      return;
    }

    await _subscription?.cancel();
    _fallbackPollTimer?.cancel();

    Future<void> emitPosition(Position position) async {
      if (position.accuracy > 120) return;
      _lastFixAt = DateTime.now();
      onLocation(
        LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          timestamp: position.timestamp,
        ),
      );
    }

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: _settings(),
      );
      await emitPosition(first);
    } catch (_) {
      // Keep stream startup resilient when first fix is delayed.
    }

    _subscription = Geolocator.getPositionStream(
      locationSettings: _settings(),
    ).listen((position) => emitPosition(position));

    _fallbackPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final last = _lastFixAt;
      if (last != null &&
          DateTime.now().difference(last) < const Duration(seconds: 5)) {
        return;
      }
      try {
        final fresh = await Geolocator.getCurrentPosition(
          locationSettings: _settings(),
        );
        await emitPosition(fresh);
      } catch (_) {
        // Ignore polling errors and wait for next cycle.
      }
    });
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: true,
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    _lastFixAt = null;
  }
}
