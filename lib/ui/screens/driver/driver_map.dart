import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/constants.dart";
import "../../widgets/map_marker.dart";

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  bool _followMe = true;
  double _zoom = 16;
  LatLng? _lastAutoCenter;

  void _centerOn(LatLng point) {
    _mapController.move(point, _zoom);
    _lastAutoCenter = point;
  }

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

  bool _shouldRecenter(LatLng point) {
    final current = _lastAutoCenter;
    if (current == null) return true;
    final meters = _distance.as(LengthUnit.Meter, current, point);
    return meters > 20;
  }

  @override
  Widget build(BuildContext context) {
    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final driverProvider = context.watch<DriverProvider>();
    final self = driverProvider.self;
    final tripProvider = context.watch<TripProvider>();
    final activeTrip = self == null
        ? null
        : tripProvider.latestActiveForDriver(self.id);
    final isVisible = (self?.status ?? "").toLowerCase().startsWith(
      "disponible",
    );
    final point = LatLng(
      self?.location.latitude ?? 19.4326,
      self?.location.longitude ?? -99.1332,
    );
    final selfTrack = self == null
        ? <LatLng>[]
        : driverProvider
              .pathForDriver(self.id)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
    final hasAssignedTrip =
        activeTrip != null &&
        (activeTrip.status == "assigned" || activeTrip.status == "accepted");
    final routePath = !hasAssignedTrip
        ? <LatLng>[]
        : activeTrip.routePoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
    final showSelfTrack = hasAssignedTrip && selfTrack.length > 1;

    final mustMove = _followMe && _shouldRecenter(point);
    if (mustMove) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerOn(point);
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
                initialCenter: point,
                initialZoom: 16,
                maxZoom: 19,
                onPositionChanged: (position, hasGesture) {
                  _zoom = position.zoom;
                  if (hasGesture && _followMe) {
                    setState(() => _followMe = false);
                  }
                },
              ),
              children: [
                _baseLayer(mapTheme),
                if (routePath.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePath,
                        strokeWidth: 4,
                        color: AppConstants.accent.withValues(alpha: 0.95),
                      ),
                    ],
                  ),
                if (showSelfTrack)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: selfTrack,
                        strokeWidth: 2,
                        color: Colors.cyanAccent.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 122,
                      height: 82,
                      child: MapMarker(
                        label: self?.name ?? "Driver",
                        active: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _StatusChip(status: self?.status ?? "Offline"),
            ),
            Positioned(
              right: 10,
              top: 96,
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
                      _centerOn(point);
                      setState(() => _followMe = true);
                    },
                  ),
                  const SizedBox(height: 8),
                  _CircleAction(
                    icon: Icons.add_rounded,
                    onTap: () {
                      _zoom = (_zoom + 1).clamp(3, 19);
                      _mapController.move(_mapController.camera.center, _zoom);
                    },
                  ),
                  const SizedBox(height: 8),
                  _CircleAction(
                    icon: Icons.remove_rounded,
                    onTap: () {
                      _zoom = (_zoom - 1).clamp(3, 19);
                      _mapController.move(_mapController.camera.center, _zoom);
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

class _AvailabilityDock extends StatelessWidget {
  const _AvailabilityDock({required this.isVisible, required this.onToggle});

  final bool isVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isVisible ? const Color(0xFF2FEA8A) : const Color(0xFFFF5F73);
    final title = isVisible ? "VISIBLE" : "INVISIBLE";
    final subtitle = isVisible
        ? "Recibiendo viajes"
        : "Oculto sin asignaciones";

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
