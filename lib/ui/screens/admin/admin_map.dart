import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../services/map_service.dart";
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

  TileLayer _baseLayer(MapThemeMode mode) {
    final url = switch (mode) {
      MapThemeMode.flow => AppConstants.tileModernUrl,
      MapThemeMode.dark => AppConstants.tileNightUrl,
      MapThemeMode.satellite => AppConstants.tileSatelliteUrl,
    };
    return TileLayer(
      urlTemplate: url,
      fallbackUrl: AppConstants.tileFallbackUrl,
      retinaMode: false,
      tileDisplay: const TileDisplay.instantaneous(),
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

  Color _driverTrackColor(String id) {
    final bucket = id.codeUnits.fold<int>(0, (sum, c) => sum + c) % 4;
    switch (bucket) {
      case 0:
        return Colors.cyanAccent;
      case 1:
        return Colors.lightGreenAccent;
      case 2:
        return Colors.orangeAccent;
      default:
        return Colors.pinkAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final allDrivers = context.watch<DriverProvider>().drivers;
    final driverProvider = context.watch<DriverProvider>();
    final trips = context.watch<TripProvider>().trips;
    final mapService = MapService();
    final center = mapService.centerFromDrivers(allDrivers);
    final online = allDrivers.where((d) => d.isOnline).length;

    List<LatLng> activeTripRoute = <LatLng>[];
    for (final trip in trips) {
      if (trip.status != "assigned" && trip.status != "accepted") continue;
      if (trip.routePoints.isEmpty) continue;
      activeTripRoute = trip.routePoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      break;
    }

    final mustMove =
        _followFleet && _shouldRecenter(center) && allDrivers.isNotEmpty;
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
                initialZoom: mapService.dynamicZoom(allDrivers.length),
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
                if (activeTripRoute.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: activeTripRoute,
                        strokeWidth: 4,
                        color: AppConstants.accent.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                PolylineLayer(
                  polylines: allDrivers
                      .where(
                        (d) => driverProvider.pathForDriver(d.id).length > 1,
                      )
                      .map(
                        (driver) => Polyline(
                          points: driverProvider
                              .pathForDriver(driver.id)
                              .map((p) => LatLng(p.latitude, p.longitude))
                              .toList(),
                          strokeWidth: 2,
                          color: _driverTrackColor(
                            driver.id,
                          ).withValues(alpha: 0.6),
                        ),
                      )
                      .toList(),
                ),
                MarkerLayer(
                  markers: allDrivers
                      .map(
                        (d) => Marker(
                          point: LatLng(
                            d.location.latitude,
                            d.location.longitude,
                          ),
                          width: 122,
                          height: 82,
                          child: MapMarker(label: d.name, active: d.isOnline),
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
                label: "${allDrivers.length} drivers • $online online",
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
