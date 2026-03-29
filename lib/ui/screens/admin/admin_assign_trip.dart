import "dart:async";

import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../models/driver_model.dart";
import "../../../models/location_model.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../services/map_service.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";
import "../../widgets/driver_card.dart";
import "../../widgets/trip_card.dart";

class AdminAssignTrip extends StatefulWidget {
  const AdminAssignTrip({super.key});

  @override
  State<AdminAssignTrip> createState() => _AdminAssignTripState();
}

class _AdminAssignTripState extends State<AdminAssignTrip> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final MapService _mapService = MapService();
  String? _selectedDriverId;
  LatLng? _originPoint;
  LatLng? _destPoint;
  RouteEstimate? _routeEstimate;
  List<AddressSuggestion> _originSuggestions = <AddressSuggestion>[];
  List<AddressSuggestion> _destSuggestions = <AddressSuggestion>[];
  Timer? _originDebounce;
  Timer? _destDebounce;
  bool _originLoading = false;
  bool _destLoading = false;
  bool _quoteLoading = false;

  @override
  void dispose() {
    _originDebounce?.cancel();
    _destDebounce?.cancel();
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_selectedDriverId == null ||
        _originCtrl.text.trim().isEmpty ||
        _destCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selecciona driver, origen y destino antes de asignar"),
        ),
      );
      return;
    }
    final tripProvider = context.read<TripProvider>();
    final drivers = context.read<DriverProvider>().drivers;
    DriverModel? selected;
    for (final driver in drivers) {
      if (driver.id == _selectedDriverId) {
        selected = driver;
        break;
      }
    }
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Driver no disponible en este momento")),
      );
      return;
    }
    if (!_isDriverSelectable(selected, tripProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ese driver esta ocupado o no disponible. Selecciona otro.",
          ),
        ),
      );
      return;
    }
    final estimate = await _resolveRouteEstimate();
    if (!mounted || estimate == null) return;

    tripProvider.assignTrip(
      driverId: _selectedDriverId!,
      origin: _originCtrl.text.trim(),
      destination: _destCtrl.text.trim(),
      distanceMiles: estimate.distanceMiles,
      durationMinutes: estimate.durationMinutes,
      fareUsd: estimate.fareUsd,
      routePoints: estimate.path
          .map(
            (p) => LocationModel(latitude: p.latitude, longitude: p.longitude),
          )
          .toList(),
      originLocation: LocationModel(
        latitude: estimate.path.first.latitude,
        longitude: estimate.path.first.longitude,
      ),
      destinationLocation: LocationModel(
        latitude: estimate.path.last.latitude,
        longitude: estimate.path.last.longitude,
      ),
    );
    setState(() {
      _originPoint = null;
      _destPoint = null;
      _routeEstimate = null;
      _originSuggestions = <AddressSuggestion>[];
      _destSuggestions = <AddressSuggestion>[];
    });
    _originCtrl.clear();
    _destCtrl.clear();
  }

  void _onAddressChanged(bool origin, String value) {
    final normalized = value.trim();
    setState(() {
      if (origin) {
        _originPoint = null;
      } else {
        _destPoint = null;
      }
      _routeEstimate = null;
    });
    if (origin) {
      _originDebounce?.cancel();
      if (normalized.length < 3) {
        setState(() {
          _originLoading = false;
          _originSuggestions = <AddressSuggestion>[];
        });
        return;
      }
      setState(() => _originLoading = true);
      _originDebounce = Timer(
        const Duration(milliseconds: 320),
        () => _searchAddress(origin: true, query: normalized),
      );
      return;
    }

    _destDebounce?.cancel();
    if (normalized.length < 3) {
      setState(() {
        _destLoading = false;
        _destSuggestions = <AddressSuggestion>[];
      });
      return;
    }
    setState(() => _destLoading = true);
    _destDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _searchAddress(origin: false, query: normalized),
    );
  }

  Future<RouteEstimate?> _resolveRouteEstimate() async {
    if (_quoteLoading) return _routeEstimate;
    final existing = _routeEstimate;
    if (existing != null && existing.path.isNotEmpty) {
      return existing;
    }

    setState(() => _quoteLoading = true);
    final proximity = _resolveProximity(context.read<DriverProvider>().drivers);
    LatLng? from = _originPoint;
    LatLng? to = _destPoint;
    from ??= await _mapService.geocodeAddress(
      _originCtrl.text.trim(),
      proximity: proximity,
    );
    to ??= await _mapService.geocodeAddress(
      _destCtrl.text.trim(),
      proximity: proximity,
    );

    if (from == null || to == null) {
      if (mounted) {
        setState(() => _quoteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo resolver la ruta")),
        );
      }
      return null;
    }

    final estimate = await _mapService.calculateRoute(
      origin: from,
      destination: to,
    );
    if (!mounted) return estimate;
    setState(() {
      _originPoint = from;
      _destPoint = to;
      _routeEstimate = estimate;
      _quoteLoading = false;
    });
    return estimate;
  }

  Future<void> _searchAddress({
    required bool origin,
    required String query,
  }) async {
    final drivers = context.read<DriverProvider>().drivers;
    final proximity = _resolveProximity(drivers);
    final data = await _mapService.autocompleteAddress(
      query,
      proximity: proximity,
    );
    if (!mounted) return;

    final latest = origin ? _originCtrl.text.trim() : _destCtrl.text.trim();
    if (latest != query) return;

    setState(() {
      if (origin) {
        _originLoading = false;
        _originSuggestions = data;
      } else {
        _destLoading = false;
        _destSuggestions = data;
      }
    });
  }

  LatLng? _resolveProximity(List<DriverModel> drivers) {
    if (drivers.isEmpty) return null;

    if (_selectedDriverId != null) {
      for (final driver in drivers) {
        if (driver.id == _selectedDriverId) {
          return LatLng(driver.location.latitude, driver.location.longitude);
        }
      }
    }

    final center = _mapService.centerFromDrivers(drivers);
    return center;
  }

  void _selectAddress(bool origin, AddressSuggestion item) {
    setState(() {
      if (origin) {
        _originCtrl.text = item.fullAddress;
        _originPoint = item.point;
        _originSuggestions = <AddressSuggestion>[];
      } else {
        _destCtrl.text = item.fullAddress;
        _destPoint = item.point;
        _destSuggestions = <AddressSuggestion>[];
      }
      _routeEstimate = null;
    });
    if (_originPoint != null && _destPoint != null) {
      unawaited(_resolveRouteEstimate());
    }
  }

  bool _isDriverBusy(DriverModel driver, TripProvider tripProvider) {
    final active = tripProvider.latestActiveForDriver(driver.id);
    return active != null;
  }

  bool _isDriverVisible(DriverModel driver) {
    final status = driver.status.toLowerCase();
    if (status.contains("invisible") || status.contains("no disponible")) {
      return false;
    }
    return true;
  }

  bool _isDriverSelectable(DriverModel driver, TripProvider tripProvider) {
    if (!driver.isOnline) return false;
    if (!_isDriverVisible(driver)) return false;
    if (_isDriverBusy(driver, tripProvider)) return false;
    return true;
  }

  String _driverDispatchStatus(DriverModel driver, TripProvider tripProvider) {
    if (!driver.isOnline) return "Offline";
    if (_isDriverBusy(driver, tripProvider)) return "Ocupado en otro viaje";
    if (!_isDriverVisible(driver)) return "No disponible";
    return "Disponible";
  }

  @override
  Widget build(BuildContext context) {
    final drivers = context.watch<DriverProvider>().drivers;
    final tripProvider = context.watch<TripProvider>();
    final trips = tripProvider.trips;
    final activeDrivers = drivers.where((d) => d.isOnline).toList();
    final assignableCount = activeDrivers
        .where((d) => _isDriverSelectable(d, tripProvider))
        .length;
    final busyCount = activeDrivers
        .where((d) => _isDriverBusy(d, tripProvider))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Asignacion manual",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                CustomInput(
                  controller: _originCtrl,
                  hint: "Origen",
                  prefixIcon: Icons.trip_origin_rounded,
                  onChanged: (value) => _onAddressChanged(true, value),
                ),
                _AddressSuggestions(
                  loading: _originLoading,
                  items: _originSuggestions,
                  onTap: (item) => _selectAddress(true, item),
                ),
                const SizedBox(height: 10),
                CustomInput(
                  controller: _destCtrl,
                  hint: "Destino",
                  prefixIcon: Icons.flag_outlined,
                  onChanged: (value) => _onAddressChanged(false, value),
                ),
                _AddressSuggestions(
                  loading: _destLoading,
                  items: _destSuggestions,
                  onTap: (item) => _selectAddress(false, item),
                ),
                if (_quoteLoading) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                if (_routeEstimate != null) ...[
                  const SizedBox(height: 10),
                  _QuoteCard(estimate: _routeEstimate!),
                ],
                const SizedBox(height: 12),
                CustomButton(
                  label: "Asignar viaje",
                  onPressed: _assign,
                  leading: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Selecciona driver",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          "Activos: ${activeDrivers.length} • Disponibles: $assignableCount • Ocupados: $busyCount",
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 10),
        if (activeDrivers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text("No hay drivers conectados en este momento"),
            ),
          ),
        ...activeDrivers.map((driver) {
          final selectable = _isDriverSelectable(driver, tripProvider);
          final viewDriver = driver.copyWith(
            status: _driverDispatchStatus(driver, tripProvider),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Opacity(
              opacity: selectable ? 1 : 0.56,
              child: DriverCard(
                driver: viewDriver,
                selected: driver.id == _selectedDriverId,
                onTap: () {
                  if (!selectable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "${driver.name} no esta disponible para asignacion",
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _selectedDriverId = driver.id);
                },
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        const Text(
          "Estado de viajes",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (trips.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text("Aun no hay viajes asignados"),
            ),
          ),
        ...trips.map(
          (trip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TripCard(trip: trip),
          ),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.estimate});

  final RouteEstimate estimate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2CFFFFFF)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _QuotePill(
            icon: Icons.route_rounded,
            label: milesText(estimate.distanceMiles),
          ),
          _QuotePill(
            icon: Icons.schedule_rounded,
            label: "${estimate.durationMinutes.toStringAsFixed(0)} min",
          ),
          _QuotePill(
            icon: Icons.attach_money_rounded,
            label: usd(estimate.fareUsd),
          ),
        ],
      ),
    );
  }
}

class _QuotePill extends StatelessWidget {
  const _QuotePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF191919),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AddressSuggestions extends StatelessWidget {
  const _AddressSuggestions({
    required this.loading,
    required this.items,
    required this.onTap,
  });

  final bool loading;
  final List<AddressSuggestion> items;
  final ValueChanged<AddressSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(6, 6, 6, 0),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              "Buscando direcciones...",
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        children: items
            .map(
              (item) => ListTile(
                dense: true,
                horizontalTitleGap: 8,
                leading: const Icon(
                  Icons.place_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                title: Text(
                  item.mainText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  item.secondaryText.isEmpty
                      ? item.fullAddress
                      : item.secondaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                ),
                onTap: () => onTap(item),
              ),
            )
            .toList(),
      ),
    );
  }
}
