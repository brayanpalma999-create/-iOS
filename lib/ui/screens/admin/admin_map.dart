import "dart:async";

import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart" as gmap;
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../services/location_service.dart";
import "../../../services/map_service.dart";
import "../../../utils/app_text.dart";
import "../../../utils/google_map_config.dart";
import "../../../utils/google_map_marker_factory.dart";
import "../../../utils/helpers.dart";

class AdminMap extends StatefulWidget {
  const AdminMap({super.key});

  @override
  State<AdminMap> createState() => _AdminMapState();
}

class _AdminMapState extends State<AdminMap> {
  static const List<Color> _routePalette = <Color>[
    Color(0xFFFFB84D),
    Color(0xFF54A9FF),
    Color(0xFFFF6E97),
    Color(0xFF53E3D6),
    Color(0xFFC08BFF),
    Color(0xFFFF7A52),
  ];

  final Distance _distance = const Distance();

  bool _followFleet = true;
  double _zoom = 14;
  LatLng? _lastAutoCenter;
  bool _seededViewerLocation = false;
  LatLng? _viewerLocation;
  bool _routesExpanded = false;

  gmap.GoogleMapController? _mapController;
  LatLng? _cameraCenter;
  DateTime? _cameraCommandUntil;

  bool _mapReady = false;
  String? _mapError;
  int _mapReloadSeed = 0;
  Timer? _mapWatchdogTimer;

  _AdminMapScene? _currentScene;
  String? _appliedSceneKey;

  Set<gmap.Marker> _markers = <gmap.Marker>{};
  Set<gmap.Polyline> _polylines = <gmap.Polyline>{};
  Set<gmap.Circle> _circles = <gmap.Circle>{};

  @override
  void initState() {
    super.initState();
    _startMapWatchdog();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededViewerLocation) return;
    _seededViewerLocation = true;
    _primeViewerLocation();
  }

  @override
  void dispose() {
    _mapWatchdogTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
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
      // Keep the map usable while location warms up.
    }
  }

  String _mapInstanceKey(MapThemeMode mode) {
    return "admin-map-${mode.name}-$_mapReloadSeed";
  }

  void _startMapWatchdog() {
    _mapWatchdogTimer?.cancel();
    _mapWatchdogTimer = Timer(const Duration(seconds: 18), () {
      if (!mounted || _mapReady) return;
      setState(() {
        _mapError = context.txt(
          es: "La conexion del mapa va lenta. Intenta mover o acercar para activarlo.",
          en: "The map connection is slow. Try moving or zooming to wake it up.",
        );
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
        _circles = <gmap.Circle>{};
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
    if (_followFleet && mounted) {
      setState(() => _followFleet = false);
    }
  }

  Future<void> _applyScene(_AdminMapScene scene) async {
    final activeCarMarker = await GoogleMapMarkerFactory.carMarker(
      active: true,
      compact: true,
    );
    final inactiveCarMarker = await GoogleMapMarkerFactory.carMarker(
      active: false,
      compact: true,
    );
    if (!mounted || _currentScene?.key != scene.key) return;

    final circles = scene.hotspots
        .asMap()
        .entries
        .map(
          (entry) => gmap.Circle(
            circleId: gmap.CircleId("hotspot-${entry.key}"),
            center: AppGoogleMapConfig.latLng(entry.value.center),
            radius: 180 + (entry.value.strength * 70),
            fillColor: const Color(0x243DDC97),
            strokeColor: const Color(0x883DDC97),
            strokeWidth: 1,
          ),
        )
        .toSet();

    final polylines = <gmap.Polyline>{};
    for (final route in scene.routes) {
      final points = AppGoogleMapConfig.latLngs(route.path);
      polylines.add(
        gmap.Polyline(
          polylineId: gmap.PolylineId("route-shadow-${route.tripId}"),
          points: points,
          color: const Color(0xB0000000),
          width: 9,
          geodesic: false,
          zIndex: 1,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
      polylines.add(
        gmap.Polyline(
          polylineId: gmap.PolylineId("route-${route.tripId}"),
          points: points,
          color: route.color,
          width: 6,
          geodesic: false,
          zIndex: 2,
          startCap: gmap.Cap.roundCap,
          endCap: gmap.Cap.roundCap,
          jointType: gmap.JointType.round,
        ),
      );
    }

    final markers = scene.drivers
        .map(
          (driver) => gmap.Marker(
            markerId: gmap.MarkerId("driver-${driver.id}"),
            position: AppGoogleMapConfig.latLng(driver.location),
            icon: driver.isOnline ? activeCarMarker : inactiveCarMarker,
            anchor: const Offset(0.5, 0.84),
            flat: true,
            zIndexInt: driver.isOnline ? 6 : 3,
            infoWindow: gmap.InfoWindow(title: driver.label),
          ),
        )
        .toSet();

    if (!mounted || _currentScene?.key != scene.key) return;
    setState(() {
      _circles = circles;
      _polylines = polylines;
      _markers = markers;
      _appliedSceneKey = scene.key;
    });
  }

  Future<void> _moveTo(LatLng point, {bool animated = true}) async {
    final controller = _mapController;
    if (controller == null) return;
    _cameraCommandUntil = DateTime.now().add(const Duration(milliseconds: 900));
    final update = gmap.CameraUpdate.newCameraPosition(
      gmap.CameraPosition(
        target: AppGoogleMapConfig.latLng(point),
        zoom: _zoom,
      ),
    );
    if (animated) {
      await controller.animateCamera(update);
    } else {
      await controller.moveCamera(update);
    }
    _cameraCenter = point;
    _lastAutoCenter = point;
  }

  bool _shouldRecenter(LatLng nextCenter) {
    final current = _lastAutoCenter;
    if (current == null) return true;
    final meters = _distance.as(LengthUnit.Meter, current, nextCenter);
    return meters > 30;
  }

  bool _hasRenderableLocation(dynamic driver) {
    return driver.location.latitude.abs() > 0.001 ||
        driver.location.longitude.abs() > 0.001;
  }

  List<_Hotspot> _buildHotspots(List<dynamic> drivers) {
    final points = drivers
        .where((driver) => driver.isOnline && _hasRenderableLocation(driver))
        .map(
          (driver) => LatLng(driver.location.latitude, driver.location.longitude),
        )
        .toList();
    if (points.isEmpty) return <_Hotspot>[];

    final hotspots = <_Hotspot>[];
    final consumed = <int>{};
    for (var i = 0; i < points.length; i++) {
      if (consumed.contains(i)) continue;
      final cluster = <LatLng>[points[i]];
      consumed.add(i);
      for (var j = i + 1; j < points.length; j++) {
        if (consumed.contains(j)) continue;
        final meters = _distance.as(LengthUnit.Meter, points[i], points[j]);
        if (meters <= 1400) {
          cluster.add(points[j]);
          consumed.add(j);
        }
      }
      if (cluster.length < 2) continue;
      final lat =
          cluster.fold<double>(0, (sum, item) => sum + item.latitude) /
          cluster.length;
      final lng =
          cluster.fold<double>(0, (sum, item) => sum + item.longitude) /
          cluster.length;
      hotspots.add(_Hotspot(center: LatLng(lat, lng), strength: cluster.length));
    }
    return hotspots;
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);

    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final allDrivers = context.watch<DriverProvider>().drivers;
    final renderableDrivers = allDrivers.where(_hasRenderableLocation).toList();
    final trips = context.watch<TripProvider>().trips;
    final mapService = MapService();
    final center = renderableDrivers.isNotEmpty
        ? mapService.centerFromDrivers(
            renderableDrivers,
            fallback: _viewerLocation,
          )
        : (_viewerLocation ?? const LatLng(37.0902, -95.7129));
    final online = allDrivers.where((d) => d.isOnline).length;
    final hotspots = _buildHotspots(renderableDrivers);
    final zoom = renderableDrivers.isEmpty
        ? (_viewerLocation == null ? 4.4 : 14.8)
        : mapService.dynamicZoom(renderableDrivers.length);
    final driverNames = <String, String>{
      for (final driver in allDrivers) driver.id: driver.name,
      for (final driver in allDrivers)
        if ((driver.intercomId ?? "").trim().isNotEmpty)
          driver.intercomId!.trim(): driver.name,
    };
    final activeTripRoutes = trips.asMap().entries
        .map((entry) {
          final trip = entry.value;
          if (trip.status != "assigned" &&
              trip.status != "accepted" &&
              trip.status != "picked_up") {
            return null;
          }
          final path = trip.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
          if (path.length <= 1) return null;
          final color = _routePalette[entry.key % _routePalette.length];
          final rawDriverName = driverNames[trip.driverId];
          final fallbackDriverName =
              "${t(es: "Driver", en: "Driver")} #${trip.driverId.length <= 4 ? trip.driverId : trip.driverId.substring(trip.driverId.length - 4)}";
          final driverName = compactPersonName(
            rawDriverName ?? fallbackDriverName,
          );
          return _RouteOverlay(
            tripId: trip.id,
            driverName: driverName,
            color: color,
            path: path,
          );
        })
        .whereType<_RouteOverlay>()
        .toList();

    final driverPins = renderableDrivers
        .map(
          (driver) => _DriverPin(
            id: driver.id,
            label: compactPersonName(driver.name),
            isOnline: driver.isOnline,
            location: LatLng(driver.location.latitude, driver.location.longitude),
          ),
        )
        .toList();

    final scene = _AdminMapScene(
      key:
          "${driverPins.length}:$online:${activeTripRoutes.length}:${hotspots.length}:${center.latitude.toStringAsFixed(4)}:${center.longitude.toStringAsFixed(4)}",
      drivers: driverPins,
      routes: activeTripRoutes,
      hotspots: hotspots,
    );
    _currentScene = scene;
    if (_mapReady && scene.key != _appliedSceneKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        unawaited(_applyScene(scene));
      });
    }

    final mustMove =
        _followFleet && _shouldRecenter(center) && renderableDrivers.isNotEmpty;
    if (mustMove) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_moveTo(center));
      });
    }

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
                      target: AppGoogleMapConfig.latLng(center),
                      zoom: zoom,
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
                    circles: _circles,
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
              Positioned(
                top: 48,
                left: 10,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD9161A1F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x2EFFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_tethering_error_rounded,
                          size: 15,
                          color: Color(0xFFFFC857),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _mapError!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _retryMap(Duration.zero),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              left: 10,
              child: _StatChip(
                label: renderableDrivers.isEmpty && _viewerLocation == null
                    ? t(
                        es: "Buscando ubicacion...",
                        en: "Looking for location...",
                      )
                    : "${allDrivers.length} drivers | $online online",
              ),
            ),
            if (activeTripRoutes.isNotEmpty)
              Positioned(
                left: 10,
                top: 48,
                child: _RouteLegend(
                  routes: activeTripRoutes,
                  isEnglish: context.isEnglish,
                  expanded: _routesExpanded,
                  onToggle: () =>
                      setState(() => _routesExpanded = !_routesExpanded),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: _FleetDock(
                totalDrivers: allDrivers.length,
                onlineDrivers: online,
                hotspotCount: hotspots.length,
                isEnglish: context.isEnglish,
              ),
            ),
            Positioned(
              right: 10,
              top: 96,
              child: _MapActions(
                onZoomIn: () {
                  _zoom = (_zoom + 1).clamp(3, 19);
                  unawaited(_moveTo(_cameraCenter ?? center));
                },
                onZoomOut: () {
                  _zoom = (_zoom - 1).clamp(3, 19);
                  unawaited(_moveTo(_cameraCenter ?? center));
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

class _Hotspot {
  const _Hotspot({required this.center, required this.strength});

  final LatLng center;
  final int strength;
}

class _RouteOverlay {
  const _RouteOverlay({
    required this.tripId,
    required this.driverName,
    required this.color,
    required this.path,
  });

  final String tripId;
  final String driverName;
  final Color color;
  final List<LatLng> path;
}

class _DriverPin {
  const _DriverPin({
    required this.id,
    required this.label,
    required this.isOnline,
    required this.location,
  });

  final String id;
  final String label;
  final bool isOnline;
  final LatLng location;
}

class _AdminMapScene {
  const _AdminMapScene({
    required this.key,
    required this.drivers,
    required this.routes,
    required this.hotspots,
  });

  final String key;
  final List<_DriverPin> drivers;
  final List<_RouteOverlay> routes;
  final List<_Hotspot> hotspots;
}

class _MapActions extends StatelessWidget {
  const _MapActions({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CircleAction(icon: Icons.add_rounded, onTap: onZoomIn),
        const SizedBox(height: 8),
        _CircleAction(icon: Icons.remove_rounded, onTap: onZoomOut),
      ],
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xDC111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend({
    required this.routes,
    required this.isEnglish,
    required this.expanded,
    required this.onToggle,
  });

  final List<_RouteOverlay> routes;
  final bool isEnglish;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xDE0F1113),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x28FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEnglish ? "Live routes" : "Rutas activas",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  "${routes.length}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 184),
              child: Scrollbar(
                thumbVisibility: routes.length > 5,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: route.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              isEnglish
                  ? "Tap to view active drivers"
                  : "Toca para ver los drivers activos",
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FleetDock extends StatelessWidget {
  const _FleetDock({
    required this.totalDrivers,
    required this.onlineDrivers,
    required this.hotspotCount,
    required this.isEnglish,
  });

  final int totalDrivers;
  final int onlineDrivers;
  final int hotspotCount;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xDE0F1113),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x28FFFFFF)),
        boxShadow: const [
          BoxShadow(color: Color(0x4C000000), blurRadius: 18, spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish ? "Active fleet" : "Flota activa",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  isEnglish
                      ? "$onlineDrivers online out of $totalDrivers signed in"
                      : "$onlineDrivers online de $totalDrivers registrados en sesion",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x191EDB9D),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x4F3DDC97)),
            ),
            child: Text(
              "$hotspotCount hotspots",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF8DF5C6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
