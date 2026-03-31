import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../services/location_service.dart";
import "../../../services/map_service.dart";
import "../../../utils/app_text.dart";
import "../../../utils/constants.dart";
import "../../widgets/map_marker.dart";

class AdminMap extends StatefulWidget {
  const AdminMap({super.key});

  @override
  State<AdminMap> createState() => _AdminMapState();
}

class _AdminMapState extends State<AdminMap> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  bool _followFleet = true;
  double _zoom = 14;
  LatLng? _lastAutoCenter;
  bool _forceStableTiles = false;
  DateTime? _lastTileErrorAt;
  int _tileErrorBurst = 0;
  bool _seededViewerLocation = false;
  LatLng? _viewerLocation;

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
      // Keep map usable even if location takes longer than expected.
    }
  }

  void _onTileError(Object error) {
    if (!AppConstants.hasMapboxToken || _forceStableTiles) return;
    final now = DateTime.now();
    final last = _lastTileErrorAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 4)) {
      _tileErrorBurst += 1;
    } else {
      _tileErrorBurst = 1;
    }
    _lastTileErrorAt = now;
    if (_tileErrorBurst >= 4 && mounted) {
      setState(() => _forceStableTiles = true);
    }
  }

  TileLayer _baseLayer(MapThemeMode mode) {
    final mapboxEnabled = AppConstants.hasMapboxToken && !_forceStableTiles;
    final url = mapboxEnabled
        ? switch (mode) {
            MapThemeMode.flow => AppConstants.tileModernUrl,
            MapThemeMode.dark => AppConstants.tileNightUrl,
            MapThemeMode.satellite => AppConstants.tileSatelliteUrl,
          }
        : AppConstants.tileFallbackUrl;
    return TileLayer(
      urlTemplate: url,
      fallbackUrl: AppConstants.tileFallbackBackupUrl,
      retinaMode: false,
      errorTileCallback: (_, error, stackTrace) => _onTileError(error),
      evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
      userAgentPackageName: "com.example.atob_app",
      keepBuffer: 1,
      panBuffer: 0,
      maxNativeZoom: 19,
    );
  }

  void _moveTo(LatLng point) {
    _mapController.move(point, _zoom);
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
          (driver) =>
              LatLng(driver.location.latitude, driver.location.longitude),
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
      hotspots.add(
        _Hotspot(center: LatLng(lat, lng), strength: cluster.length),
      );
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
    final activeTripRoutes = trips
        .where((trip) => trip.status == "assigned" || trip.status == "accepted")
        .map(
          (trip) => trip.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
        )
        .where((path) => path.length > 1)
        .toList();

    final mustMove =
        _followFleet && _shouldRecenter(center) && renderableDrivers.isNotEmpty;
    if (mustMove) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _moveTo(center);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: 19,
                onPositionChanged: (position, hasGesture) {
                  _zoom = position.zoom;
                  if (hasGesture && _followFleet) {
                    setState(() => _followFleet = false);
                  }
                },
              ),
              children: [
                _baseLayer(mapTheme),
                if (hotspots.isNotEmpty)
                  CircleLayer(
                    circles: hotspots
                        .map(
                          (hotspot) => CircleMarker(
                            point: hotspot.center,
                            radius: 18 + (hotspot.strength * 6),
                            color: const Color(0x243DDC97),
                            borderStrokeWidth: 1.4,
                            borderColor: const Color(0x883DDC97),
                          ),
                        )
                        .toList(),
                  ),
                if (activeTripRoutes.isNotEmpty)
                  PolylineLayer(
                    polylines: activeTripRoutes
                        .map(
                          (path) => Polyline(
                            points: path,
                            strokeWidth: 4,
                            color: AppConstants.accent.withValues(alpha: 0.84),
                          ),
                        )
                        .toList(),
                  ),
                MarkerLayer(
                  markers: renderableDrivers
                      .map(
                        (d) => Marker(
                          point: LatLng(
                            d.location.latitude,
                            d.location.longitude,
                          ),
                          width: 122,
                          height: 82,
                          child: MapMarker(
                            label: d.name,
                            active: d.isOnline,
                            carMode: true,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
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
            if (_forceStableTiles)
              Positioned(
                left: 10,
                top: 48,
                child: _StatChip(
                  label: t(
                    es: "Modo mapa estable activo",
                    en: "Stable map mode active",
                  ),
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
                followEnabled: _followFleet,
                onFollowTap: () => setState(() => _followFleet = !_followFleet),
                onCenterTap: () {
                  _moveTo(center);
                  setState(() => _followFleet = true);
                },
                onZoomIn: () {
                  _zoom = (_zoom + 1).clamp(3, 19);
                  _mapController.move(_mapController.camera.center, _zoom);
                },
                onZoomOut: () {
                  _zoom = (_zoom - 1).clamp(3, 19);
                  _mapController.move(_mapController.camera.center, _zoom);
                },
              ),
            ),
          ],
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

class _MapActions extends StatelessWidget {
  const _MapActions({
    required this.followEnabled,
    required this.onFollowTap,
    required this.onCenterTap,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool followEnabled;
  final VoidCallback onFollowTap;
  final VoidCallback onCenterTap;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CircleAction(
          icon: followEnabled
              ? Icons.near_me_rounded
              : Icons.near_me_disabled_rounded,
          onTap: onFollowTap,
        ),
        const SizedBox(height: 8),
        _CircleAction(icon: Icons.my_location_rounded, onTap: onCenterTap),
        const SizedBox(height: 8),
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
                  style: TextStyle(fontWeight: FontWeight.w800),
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
