// ignore_for_file: experimental_member_use

import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_compass/flutter_compass.dart";
import "package:google_maps_flutter/google_maps_flutter.dart" as gmap;
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../models/trip_model.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../services/location_service.dart";
import "../../../utils/app_text.dart";
import "../../../utils/google_map_config.dart";
import "../../../utils/google_map_marker_factory.dart";
import "../../../utils/helpers.dart";

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final Distance _distance = const Distance();

  bool _followMe = true;
  double _zoom = 16;
  LatLng? _lastAutoCenter;
  bool _seededViewerLocation = false;
  LatLng? _viewerLocation;
  String? _lastRouteFocusKey;
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _deviceHeading;
  double? _lastAppliedRotation;

  gmap.GoogleMapController? _mapController;
  LatLng? _cameraCenter;
  DateTime? _cameraCommandUntil;

  bool _mapReady = false;
  String? _mapError;
  int _mapReloadSeed = 0;
  Timer? _mapWatchdogTimer;

  _DriverMapScene? _currentScene;
  String? _appliedSceneKey;

  Set<gmap.Marker> _markers = <gmap.Marker>{};
  Set<gmap.Polyline> _polylines = <gmap.Polyline>{};

  @override
  void initState() {
    super.initState();
    _startMapWatchdog();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      setState(() => _deviceHeading = heading);
    });
  }

  @override
  void dispose() {
    _mapWatchdogTimer?.cancel();
    _compassSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededViewerLocation) return;
    _seededViewerLocation = true;
    _primeViewerLocation();
  }

  Future<void> _primeViewerLocation() async {
    final service = context.read<LocationService>();
    try {
      final current = await service.current();
      if (!mounted) return;
      setState(() {
        _viewerLocation = LatLng(current.latitude, current.longitude);
      });
    } catch (_) {
      // Keep rendering even if the first precise fix takes longer.
    }
  }

  String _mapInstanceKey(MapThemeMode mode) {
    return "driver-map-${mode.name}-$_mapReloadSeed";
  }

  void _startMapWatchdog() {
    _mapWatchdogTimer?.cancel();
    _mapWatchdogTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || _mapReady) return;
      setState(() {
        _mapError = context.txt(
          es: "El mapa no termino de cargar. Reintentando...",
          en: "The map did not finish loading. Retrying...",
        );
        _mapReloadSeed += 1;
      });
    });
  }

  void _retryMap([Duration delay = const Duration(milliseconds: 200)]) {
    _mapWatchdogTimer?.cancel();
    Future<void>.delayed(delay, () {
      if (!mounted) return;
      setState(() {
        _mapReady = false;
        _mapError = null;
        _appliedSceneKey = null;
        _markers = <gmap.Marker>{};
        _polylines = <gmap.Polyline>{};
        _mapReloadSeed += 1;
      });
      _startMapWatchdog();
    });
  }

  void _handleMapCreated(gmap.GoogleMapController controller) {
    _mapController = controller;
    _mapWatchdogTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _mapReady = true;
      _mapError = null;
    });
    final scene = _currentScene;
    if (scene != null) {
      unawaited(_applyScene(scene));
    }
  }

  void _handleCameraMoveStarted() {
    final until = _cameraCommandUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      return;
    }
    if (_followMe && mounted) {
      setState(() => _followMe = false);
    }
  }

  Future<void> _applyScene(_DriverMapScene scene) async {
    final selfMarker = await GoogleMapMarkerFactory.carMarker(
      active: scene.selfActive,
    );
    final pickupMarker = scene.pickupPoint == null
        ? null
        : await GoogleMapMarkerFactory.stopMarker(
            icon: Icons.train_rounded,
            colorValue: (scene.pickupComplete
                    ? const Color(0xFF8D949E)
                    : const Color(0xFF74B9FF))
                .toARGB32(),
          );
    final destinationMarker = scene.destinationPoint == null
        ? null
        : await GoogleMapMarkerFactory.stopMarker(
            icon: Icons.home_rounded,
            colorValue: const Color(0xFFFFD166).toARGB32(),
          );

    if (!mounted || _currentScene?.key != scene.key) return;

    final polylines = <gmap.Polyline>{};
    if (scene.traveledPath.length > 1) {
      final points = AppGoogleMapConfig.latLngs(scene.traveledPath);
      polylines.add(
        gmap.Polyline(
          polylineId: const gmap.PolylineId("traveled-shadow"),
          points: points,
          color: const Color(0xB06B2D00),
          width: 10,
          zIndex: 1,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
      polylines.add(
        gmap.Polyline(
          polylineId: const gmap.PolylineId("traveled"),
          points: points,
          color: const Color(0xFFFF9B2F),
          width: 7,
          zIndex: 2,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
    }
    if (scene.remainingPath.length > 1) {
      final points = AppGoogleMapConfig.latLngs(scene.remainingPath);
      polylines.add(
        gmap.Polyline(
          polylineId: const gmap.PolylineId("remaining-shadow"),
          points: points,
          color: const Color(0xB0000000),
          width: 10,
          zIndex: 3,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
      polylines.add(
        gmap.Polyline(
          polylineId: const gmap.PolylineId("remaining"),
          points: points,
          color: const Color(0xFFFF5A5F),
          width: 7,
          zIndex: 4,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
    }

    final markers = <gmap.Marker>{
      gmap.Marker(
        markerId: const gmap.MarkerId("driver-self"),
        position: AppGoogleMapConfig.latLng(scene.point),
        icon: selfMarker,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        rotation: scene.headingDegrees,
        zIndexInt: 10,
        infoWindow: gmap.InfoWindow(title: scene.label),
      ),
    };
    if (scene.pickupPoint != null && pickupMarker != null) {
      markers.add(
        gmap.Marker(
          markerId: const gmap.MarkerId("pickup"),
          position: AppGoogleMapConfig.latLng(scene.pickupPoint!),
          icon: pickupMarker,
          anchor: const Offset(0.5, 0.84),
          zIndexInt: 3,
          infoWindow: gmap.InfoWindow(
            title: context.txt(es: "Recogida", en: "Pickup"),
          ),
        ),
      );
    }
    if (scene.destinationPoint != null && destinationMarker != null) {
      markers.add(
        gmap.Marker(
          markerId: const gmap.MarkerId("destination"),
          position: AppGoogleMapConfig.latLng(scene.destinationPoint!),
          icon: destinationMarker,
          anchor: const Offset(0.5, 0.84),
          zIndexInt: 3,
          infoWindow: gmap.InfoWindow(
            title: context.txt(es: "Destino", en: "Destination"),
          ),
        ),
      );
    }

    if (!mounted || _currentScene?.key != scene.key) return;
    setState(() {
      _polylines = polylines;
      _markers = markers;
      _appliedSceneKey = scene.key;
    });
  }

  Future<void> _moveCamera({
    required LatLng center,
    double? zoomOverride,
    double? bearing,
    double tilt = 0,
    bool animated = true,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    if (zoomOverride != null) {
      _zoom = zoomOverride;
    }
    _cameraCommandUntil = DateTime.now().add(const Duration(milliseconds: 950));
    final update = gmap.CameraUpdate.newCameraPosition(
      gmap.CameraPosition(
        target: AppGoogleMapConfig.latLng(center),
        zoom: _zoom,
        bearing: bearing ?? 0,
        tilt: tilt,
      ),
    );
    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
    _cameraCenter = center;
    _lastAutoCenter = center;
  }

  void _centerOn(LatLng point, {double? zoomOverride}) {
    unawaited(
      _moveCamera(
        center: point,
        zoomOverride: zoomOverride,
        bearing: 0,
        tilt: 0,
      ),
    );
  }

  void _centerOnWithRotation(
    LatLng point, {
      double? zoomOverride,
      double? rotationOverride,
    }) {
    unawaited(
      _moveCamera(
        center: point,
        zoomOverride: zoomOverride,
        bearing: rotationOverride ?? 0,
        tilt: rotationOverride == null ? 0 : 52,
      ),
    );
    if (rotationOverride != null) {
      _lastAppliedRotation = rotationOverride;
    }
  }

  void _fitRoute(List<LatLng> path, LatLng currentPoint) {
    unawaited(_fitRouteAsync(path, currentPoint));
  }

  Future<void> _fitRouteAsync(List<LatLng> path, LatLng currentPoint) async {
    final controller = _mapController;
    if (controller == null) return;
    final points = <LatLng>[currentPoint, ...path];
    if (points.length < 2) {
      _centerOn(currentPoint);
      return;
    }
    try {
      final bounds = AppGoogleMapConfig.boundsFromLatLng(points);
      _cameraCommandUntil = DateTime.now().add(const Duration(seconds: 1));
      await controller.animateCamera(gmap.CameraUpdate.newLatLngBounds(bounds, 92));
      _cameraCenter = currentPoint;
      _lastAutoCenter = currentPoint;
      _lastAppliedRotation = 0;
    } catch (_) {
      _centerOn(currentPoint);
    }
  }

  void _focusNavigation(List<LatLng> path, LatLng currentPoint) {
    _centerOnWithRotation(
      currentPoint,
      zoomOverride: _zoom < 18.15 ? 18.15 : _zoom,
      rotationOverride: _mapRotationForHeading(_deviceHeading),
    );
  }

  bool _shouldRecenter(LatLng point) {
    final current = _lastAutoCenter;
    if (current == null) return true;
    final meters = _distance.as(LengthUnit.Meter, current, point);
    return meters > 20;
  }

  _RouteProgress _buildRouteProgress(List<LatLng> path, LatLng currentPoint) {
    if (path.isEmpty) {
      return const _RouteProgress(
        remainingPath: <LatLng>[],
        traveledPath: <LatLng>[],
        nearestIndex: 0,
        nearestMeters: 0,
      );
    }
    final nearestIndex = _nearestRouteIndex(path, currentPoint);
    final nearestMeters = _distance.as(
      LengthUnit.Meter,
      currentPoint,
      path[nearestIndex],
    );

    final traveled = path.take(nearestIndex + 1).toList();
    final remaining = path.skip(nearestIndex).toList();

    if (nearestMeters <= 28) {
      if (traveled.isNotEmpty) {
        traveled[traveled.length - 1] = currentPoint;
      }
      if (remaining.isNotEmpty) {
        remaining[0] = currentPoint;
      }
    }

    return _RouteProgress(
      traveledPath: _dedupeRoutePoints(traveled),
      remainingPath: _dedupeRoutePoints(remaining),
      nearestIndex: nearestIndex,
      nearestMeters: nearestMeters,
    );
  }

  int _nearestRouteIndex(List<LatLng> path, LatLng point) {
    var nearestIndex = 0;
    var nearestMeters = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final meters = _distance.as(LengthUnit.Meter, point, path[i]);
      if (meters < nearestMeters) {
        nearestMeters = meters;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  List<LatLng> _dedupeRoutePoints(List<LatLng> points) {
    final compacted = <LatLng>[];
    for (final point in points) {
      if (compacted.isEmpty) {
        compacted.add(point);
        continue;
      }
      final last = compacted.last;
      if ((last.latitude - point.latitude).abs() < 0.000005 &&
          (last.longitude - point.longitude).abs() < 0.000005) {
        continue;
      }
      compacted.add(point);
    }
    return compacted;
  }

  bool _hasUsableLocation(LatLng point) {
    return point.latitude.abs() > 0.001 || point.longitude.abs() > 0.001;
  }

  String _statusEnglish(String raw) {
    final value = raw.toLowerCase();
    if (value.startsWith("disponible")) return "Available (Visible)";
    if (value.contains("invisible") || value.contains("no disponible")) {
      return "Unavailable (Invisible)";
    }
    return raw;
  }

  double _speedMph(double metersPerSecond) {
    return metersPerSecond <= 0 ? 0 : metersPerSecond * 2.236936;
  }

  double _headingDegrees(List<LatLng> breadcrumb, List<LatLng> routePath) {
    if (breadcrumb.length >= 2) {
      final previous = breadcrumb[breadcrumb.length - 2];
      final current = breadcrumb.last;
      final deltaLat = current.latitude - previous.latitude;
      final deltaLng = current.longitude - previous.longitude;
      if (deltaLat.abs() > 0.000001 || deltaLng.abs() > 0.000001) {
        return _bearingBetween(previous, current);
      }
    }
    if (routePath.length >= 2) {
      return _bearingBetween(routePath.first, routePath[1]);
    }
    return 0;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final deltaLng = to.longitude - from.longitude;
    final deltaLat = to.latitude - from.latitude;
    return (90 - (math.atan2(deltaLat, deltaLng) * 180 / math.pi) + 360) % 360;
  }

  double? _mapRotationForHeading(double? heading) {
    if (heading == null || heading.isNaN) return null;
    return (360 - heading) % 360;
  }

  void _syncNavigationRotation(bool hasStartedTrip, LatLng point) {
    final rotation = _mapRotationForHeading(_deviceHeading);
    if (!_followMe || !hasStartedTrip || rotation == null) {
      if ((_lastAppliedRotation ?? 0).abs() > 0.8) {
        _lastAppliedRotation = 0;
        _centerOn(point, zoomOverride: _zoom);
      }
      return;
    }
    final last = _lastAppliedRotation;
    // Rotate more responsively: threshold of 1° for smoother tracking
    if (last != null && (last - rotation).abs() < 1.0) {
      return;
    }
    _lastAppliedRotation = rotation;
    _centerOnWithRotation(
      point,
      zoomOverride: _zoom < 17.0 ? 17.0 : _zoom,
      rotationOverride: rotation,
    );
  }

  String _compassLabel(
    String Function({required String es, required String en}) t,
  ) {
    final heading = _deviceHeading;
    if (heading == null) {
      return t(es: "Brujula", en: "Compass");
    }
    const labels = <String>["N", "NE", "E", "SE", "S", "SO", "O", "NO"];
    final index = (((heading + 22.5) % 360) / 45).floor();
    return "${labels[index]} ${heading.round()} deg";
  }

  int? _estimateMinutesToTarget(
    List<LatLng> routePath,
    LatLng target,
    double totalMinutes,
  ) {
    if (routePath.length < 2 || totalMinutes <= 0) return null;
    var targetIndex = 0;
    var closestMeters = double.infinity;
    for (var i = 0; i < routePath.length; i++) {
      final meters = _distance.as(LengthUnit.Meter, routePath[i], target);
      if (meters < closestMeters) {
        closestMeters = meters;
        targetIndex = i;
      }
    }
    final totalMeters = _polylineMeters(routePath);
    if (totalMeters <= 1) return totalMinutes.round();
    final segmentMeters =
        _polylineMeters(routePath.take(targetIndex + 1).toList());
    final ratio = (segmentMeters / totalMeters).clamp(0.05, 1.0);
    return math.max(1, (totalMinutes * ratio).round());
  }

  double _polylineMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += _distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters;
  }

  double _routeMetersBetweenIndices(
    List<LatLng> routePath,
    int startIndex,
    int endIndex,
  ) {
    if (routePath.length < 2) return 0;
    final safeStart = startIndex.clamp(0, routePath.length - 1);
    final safeEnd = endIndex.clamp(safeStart, routePath.length - 1);
    if (safeEnd <= safeStart) return 0;
    return _polylineMeters(routePath.sublist(safeStart, safeEnd + 1));
  }

  _UpcomingStepPreview? _resolveUpcomingStep(
    List<RouteStepModel> steps,
    List<LatLng> routePath,
    int currentRouteIndex,
    LatLng currentPoint,
  ) {
    if (steps.isEmpty || routePath.length < 2) return null;

    _UpcomingStepPreview? fallback;
    for (final step in steps) {
      final location = step.location;
      if (location == null) continue;
      final stepPoint = LatLng(location.latitude, location.longitude);
      final stepIndex = _nearestRouteIndex(routePath, stepPoint);
      final routeMeters = _routeMetersBetweenIndices(
        routePath,
        currentRouteIndex,
        stepIndex,
      );
      final straightMeters = _distance.as(
        LengthUnit.Meter,
        currentPoint,
        stepPoint,
      );
      final effectiveMeters = routeMeters > 1 ? routeMeters : straightMeters;
      final preview = _UpcomingStepPreview(
        step: step,
        distanceMeters: effectiveMeters,
      );
      if (effectiveMeters >= 18 && stepIndex >= currentRouteIndex) {
        return preview;
      }
      fallback ??= preview;
    }
    return fallback;
  }

  String _distanceLabel(double meters, bool isEnglish) {
    if (meters < 120) {
      return isEnglish ? "${meters.round()} ft" : "${meters.round()} m";
    }
    final miles = meters / 1609.344;
    if (miles < 0.2) {
      final feet = meters * 3.28084;
      return "${feet.round()} ft";
    }
    return "${miles.toStringAsFixed(miles < 1 ? 1 : 0)} mi";
  }

  IconData _maneuverIcon(RouteStepModel step) {
    final type = (step.maneuverType ?? "").toLowerCase();
    final modifier = (step.maneuverModifier ?? "").toLowerCase();
    if (type == "arrive") return Icons.flag_rounded;
    if (type == "roundabout") return Icons.roundabout_right_rounded;
    if (type == "merge") return Icons.merge_rounded;
    if (type == "fork") {
      return modifier.contains("left")
          ? Icons.fork_left_rounded
          : Icons.fork_right_rounded;
    }
    return switch (modifier) {
      "left" => Icons.turn_left_rounded,
      "right" => Icons.turn_right_rounded,
      "slight left" => Icons.turn_slight_left_rounded,
      "slight right" => Icons.turn_slight_right_rounded,
      "sharp left" => Icons.turn_sharp_left_rounded,
      "sharp right" => Icons.turn_sharp_right_rounded,
      "uturn" => Icons.u_turn_left_rounded,
      "straight" => Icons.straight_rounded,
      _ => Icons.navigation_rounded,
    };
  }

  String _nextStepLabel(
    _UpcomingStepPreview preview,
    String Function({required String es, required String en}) t,
  ) {
    final step = preview.step;
    final road = (step.roadName ?? "").trim();
    final distanceText = _distanceLabel(preview.distanceMeters, context.isEnglish);
    final modifier = (step.maneuverModifier ?? "").toLowerCase();
    final type = (step.maneuverType ?? "").toLowerCase();

    if (type == "arrive") {
      return t(
        es: "Llegada en $distanceText",
        en: "Arrive in $distanceText",
      );
    }

    if (type == "turn" ||
        type == "fork" ||
        type == "merge" ||
        type == "off ramp" ||
        type == "on ramp" ||
        type == "roundabout") {
      final direction = switch (modifier) {
        "left" => t(es: "izquierda", en: "left"),
        "right" => t(es: "derecha", en: "right"),
        "slight left" => t(es: "ligeramente a la izquierda", en: "slight left"),
        "slight right" => t(es: "ligeramente a la derecha", en: "slight right"),
        "sharp left" => t(es: "cerrado a la izquierda", en: "sharp left"),
        "sharp right" => t(es: "cerrado a la derecha", en: "sharp right"),
        "uturn" => t(es: "retorno", en: "u-turn"),
        _ => t(es: "frente", en: "ahead"),
      };
      if (road.isNotEmpty) {
        return t(
          es: "En $distanceText gira a la $direction hacia $road",
          en: "In $distanceText turn $direction onto $road",
        );
      }
      return t(
        es: "En $distanceText gira a la $direction",
        en: "In $distanceText turn $direction",
      );
    }

    if (road.isNotEmpty) {
      return t(
        es: "Sigue por $road durante $distanceText",
        en: "Continue on $road for $distanceText",
      );
    }

    return t(
      es: "Continua durante $distanceText",
      en: "Continue for $distanceText",
    );
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);

    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final driverProvider = context.watch<DriverProvider>();
    final self = driverProvider.self;
    final tripProvider = context.watch<TripProvider>();
    final activeTrip = self == null || self.currentTripId == null
        ? null
        : tripProvider.byId(self.currentTripId!);
    final breadcrumb = self == null
        ? const <LatLng>[]
        : driverProvider
              .pathForDriver(self.id)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
    final isVisible = (self?.status ?? "").toLowerCase().startsWith(
      "disponible",
    );
    final selfPoint = self == null
        ? null
        : LatLng(self.location.latitude, self.location.longitude);
    final hasRealSelfLocation =
        selfPoint != null && _hasUsableLocation(selfPoint);
    final point = hasRealSelfLocation
        ? selfPoint
        : (_viewerLocation ?? const LatLng(37.0902, -95.7129));
    final hasStartedTrip =
        activeTrip != null &&
        (activeTrip.status == "accepted" || activeTrip.status == "picked_up");
    final fullRoutePath = !hasStartedTrip
        ? <LatLng>[]
        : activeTrip.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
    final routeProgress = fullRoutePath.length > 1
        ? _buildRouteProgress(fullRoutePath, point)
        : null;
    final routePath = routeProgress?.remainingPath ?? fullRoutePath;
    final traveledPath = routeProgress?.traveledPath ?? const <LatLng>[];
    final routeFocusPoint = point;
    final routeFocusKey = activeTrip == null
        ? null
        : "${activeTrip.id}:${activeTrip.status}:${routePath.length}";
    final heading = _headingDegrees(breadcrumb, routePath);
    final speedMph = _speedMph(self?.location.speed ?? 0);
    final pickupPoint = activeTrip?.originLocation == null
        ? null
        : LatLng(
            activeTrip!.originLocation!.latitude,
            activeTrip.originLocation!.longitude,
          );
    final destinationPoint = activeTrip?.destinationLocation == null
        ? null
        : LatLng(
            activeTrip!.destinationLocation!.latitude,
            activeTrip.destinationLocation!.longitude,
          );
    final pickupEtaMinutes =
        activeTrip != null &&
            activeTrip.status == "accepted" &&
            pickupPoint != null
        ? _estimateMinutesToTarget(routePath, pickupPoint, activeTrip.durationMinutes)
        : null;
    final destinationEtaMinutes =
        activeTrip != null &&
            activeTrip.status == "picked_up" &&
            routePath.length > 1 &&
            activeTrip.durationMinutes > 0 &&
            destinationPoint != null
        ? _estimateMinutesToTarget(
            routePath,
            destinationPoint,
            activeTrip.durationMinutes,
          )
        : null;
    final upcomingStep =
        activeTrip != null &&
            routeProgress != null &&
            activeTrip.routeSteps.isNotEmpty
        ? _resolveUpcomingStep(
            activeTrip.routeSteps,
            fullRoutePath,
            routeProgress.nearestIndex,
            point,
          )
        : null;

    final scene = _DriverMapScene(
      key:
          "${activeTrip?.id ?? "none"}:${activeTrip?.status ?? "idle"}:${point.latitude.toStringAsFixed(5)}:${point.longitude.toStringAsFixed(5)}:${routePath.length}:${traveledPath.length}:${heading.toStringAsFixed(1)}:${isVisible ? "1" : "0"}",
      point: point,
      remainingPath: routePath,
      traveledPath: traveledPath,
      pickupPoint: pickupPoint,
      destinationPoint: destinationPoint,
      label: compactPersonName(self?.name ?? t(es: "Driver", en: "Driver")),
      selfActive: true,
      headingDegrees: heading,
      pickupComplete: activeTrip?.status == "picked_up",
    );
    _currentScene = scene;
    if (_mapReady && scene.key != _appliedSceneKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        unawaited(_applyScene(scene));
      });
    }

    final mustMove = _followMe && _shouldRecenter(routeFocusPoint);
    if (routeFocusKey == null) {
      _lastRouteFocusKey = null;
    } else if (routeFocusKey != _lastRouteFocusKey && routePath.length > 1) {
      _lastRouteFocusKey = routeFocusKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNavigation(routePath, point);
      });
    }
    if (mustMove) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (routePath.length > 1) {
          _focusNavigation(routePath, point);
        } else {
          _centerOn(point);
        }
      });
    }
    _syncNavigationRotation(hasStartedTrip, point);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x16000000)),
        ),
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
            const ColoredBox(color: Color(0xFF091018)),
            if (!AppGoogleMapConfig.isConfigured)
              Positioned.fill(
                child: Center(
                  child: Text(
                    t(
                      es: "Falta configurar Google Maps.",
                      en: "Google Maps is not configured.",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: RepaintBoundary(
                  child: gmap.GoogleMap(
                    key: ValueKey(_mapInstanceKey(mapTheme)),
                    initialCameraPosition: gmap.CameraPosition(
                      target: AppGoogleMapConfig.latLng(point),
                      zoom: !hasRealSelfLocation && _viewerLocation == null
                          ? 4.4
                          : 16,
                    ),
                    mapType: AppGoogleMapConfig.mapTypeForMode(mapTheme),
                    style: AppGoogleMapConfig.styleForMode(mapTheme),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    buildingsEnabled: true,
                    trafficEnabled: false,
                    indoorViewEnabled: false,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: _handleMapCreated,
                    onCameraMoveStarted: _handleCameraMoveStarted,
                    onCameraMove: (position) {
                      _zoom = position.zoom;
                      _cameraCenter = AppGoogleMapConfig.latLngFromGoogle(
                        position.target,
                      );
                    },
                  ),
                ),
              ),
            if (!_mapReady && _mapError == null)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x16000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_mapError != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Color(0xB8091018),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_rounded,
                            size: 34,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            t(
                              es: "Reintentando conexion del mapa",
                              en: "Retrying map connection",
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _mapError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _retryMap(Duration.zero),
                            child: Text(t(es: "Reintentar", en: "Retry")),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusChip(
                    status: self == null
                        ? (_viewerLocation == null
                              ? t(
                                  es: "Buscando ubicacion...",
                                  en: "Looking for location...",
                                )
                              : t(es: "Ubicacion lista", en: "Location ready"))
                        : hasRealSelfLocation
                        ? (context.isEnglish
                              ? _statusEnglish(self.status)
                              : self.status)
                        : t(
                            es: "Concede ubicacion exacta",
                            en: "Allow precise location",
                          ),
                  ),
                  if (pickupEtaMinutes != null) ...[
                    const SizedBox(height: 8),
                    _EtaChip(
                      icon: Icons.person_pin_circle_rounded,
                      label: t(
                        es:
                            "Recogida ${etaClock(DateTime.now().add(Duration(minutes: pickupEtaMinutes)))}",
                        en:
                            "Pickup ${etaClock(DateTime.now().add(Duration(minutes: pickupEtaMinutes)))}",
                      ),
                    ),
                  ],
                  if (destinationEtaMinutes != null) ...[
                    const SizedBox(height: 8),
                    _EtaChip(
                      icon: Icons.flag_rounded,
                      label: t(
                        es:
                            "Destino ${etaClock(DateTime.now().add(Duration(minutes: destinationEtaMinutes)))}",
                        en:
                            "Destination ${etaClock(DateTime.now().add(Duration(minutes: destinationEtaMinutes)))}",
                      ),
                    ),
                  ],
                  if (upcomingStep != null &&
                      upcomingStep.distanceMeters <= 200) ...[
                    const SizedBox(height: 8),
                    _NextTurnBanner(
                      icon: _maneuverIcon(upcomingStep.step),
                      label: _nextStepLabel(upcomingStep, t),
                      distanceMeters: upcomingStep.distanceMeters,
                      isEnglish: context.isEnglish,
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SpeedChip(label: "${speedMph.toStringAsFixed(0)} mph"),
                  const SizedBox(height: 8),
                  _CompassChip(label: _compassLabel(t)),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 54,
              child: Column(
                children: [
                  _CircleAction(
                    icon: _followMe
                        ? Icons.near_me_rounded
                        : Icons.near_me_disabled_rounded,
                    onTap: () => setState(() => _followMe = !_followMe),
                  ),
                  const SizedBox(height: 8),
                  _CircleAction(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      if (routePath.length > 1) {
                        _focusNavigation(routePath, point);
                      } else {
                        _centerOn(point);
                      }
                      setState(() => _followMe = true);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (routePath.length > 1)
                    _CircleAction(
                      icon: Icons.alt_route_rounded,
                      onTap: () {
                        _fitRoute(routePath, point);
                        setState(() => _followMe = true);
                      },
                    ),
                  if (routePath.length > 1) const SizedBox(height: 8),
                  _CircleAction(
                    icon: Icons.add_rounded,
                    onTap: () {
                      _zoom = (_zoom + 1).clamp(3, 19);
                      _centerOn(_cameraCenter ?? point, zoomOverride: _zoom);
                    },
                  ),
                  const SizedBox(height: 8),
                  _CircleAction(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      _zoom = (_zoom - 1).clamp(3, 19);
                      _centerOn(_cameraCenter ?? point, zoomOverride: _zoom);
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: _AvailabilityDock(
                isVisible: isVisible,
                isEnglish: context.isEnglish,
                onToggle: () {
                  final current = (self?.status ?? "").toLowerCase();
                  final next = current.startsWith("disponible")
                      ? "No disponible (Invisible)"
                      : "Disponible (Visible)";
                  context.read<DriverProvider>().setOperationalStatus(next);
                },
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF1161616),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xDC111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _EtaChip extends StatelessWidget {
  const _EtaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xD8191D24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3D7EC8FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF72BBFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE1111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x36FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed_rounded, size: 15, color: Color(0xFFFFC857)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _CompassChip extends StatelessWidget {
  const _CompassChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE1111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3672BBFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore_rounded, size: 15, color: Color(0xFF72BBFF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NextTurnBanner extends StatelessWidget {
  const _NextTurnBanner({
    required this.icon,
    required this.label,
    required this.distanceMeters,
    required this.isEnglish,
  });

  final IconData icon;
  final String label;
  final double distanceMeters;
  final bool isEnglish;

  String get _shortDistance {
    if (distanceMeters < 120) {
      return "${distanceMeters.round()} ${isEnglish ? "ft" : "m"}";
    }
    final miles = distanceMeters / 1609.344;
    if (miles < 0.2) return "${(distanceMeters * 3.28084).round()} ft";
    return "${miles.toStringAsFixed(miles < 1 ? 1 : 0)} mi";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xE81A1B1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40FF9B2F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFFB257)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              "$_shortDistance — $label",
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.15,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityDock extends StatelessWidget {
  const _AvailabilityDock({
    required this.isVisible,
    required this.isEnglish,
    required this.onToggle,
  });

  final bool isVisible;
  final bool isEnglish;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isVisible ? const Color(0xFF2FEA8A) : const Color(0xFFFF5F73);
    final title = isVisible ? "VISIBLE" : "INVISIBLE";
    final subtitle = isVisible
        ? (isEnglish ? "Receiving trips" : "Recibiendo viajes")
        : (isEnglish
              ? "Hidden without assignments"
              : "Oculto sin asignaciones");

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isVisible
                ? const [Color(0xFF15382A), Color(0xFF0B1F17)]
                : const [Color(0xFF3F1721), Color(0xFF230D14)],
          ),
          border: Border.all(color: color, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 14,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 1.1),
              ),
              child: Icon(
                isVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.55,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x2B000000),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                isVisible ? "ON" : "OFF",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteProgress {
  const _RouteProgress({
    required this.remainingPath,
    required this.traveledPath,
    required this.nearestIndex,
    required this.nearestMeters,
  });

  final List<LatLng> remainingPath;
  final List<LatLng> traveledPath;
  final int nearestIndex;
  final double nearestMeters;
}

class _UpcomingStepPreview {
  const _UpcomingStepPreview({
    required this.step,
    required this.distanceMeters,
  });

  final RouteStepModel step;
  final double distanceMeters;
}

class _DriverMapScene {
  const _DriverMapScene({
    required this.key,
    required this.point,
    required this.remainingPath,
    required this.traveledPath,
    required this.pickupPoint,
    required this.destinationPoint,
    required this.label,
    required this.selfActive,
    required this.headingDegrees,
    required this.pickupComplete,
  });

  final String key;
  final LatLng point;
  final List<LatLng> remainingPath;
  final List<LatLng> traveledPath;
  final LatLng? pickupPoint;
  final LatLng? destinationPoint;
  final String label;
  final bool selfActive;
  final double headingDegrees;
  final bool pickupComplete;
}
