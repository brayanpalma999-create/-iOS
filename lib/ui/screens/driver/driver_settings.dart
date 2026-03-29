import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../models/trip_model.dart";
import "../../../providers/auth_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/intercom_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../routes.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";

class DriverSettings extends StatefulWidget {
  const DriverSettings({super.key});

  @override
  State<DriverSettings> createState() => _DriverSettingsState();
}

class _DriverSettingsState extends State<DriverSettings> {
  final _nameCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = context.read<AuthProvider>().user?.name ?? "";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    context.read<AuthProvider>().updateName(name);
    context.read<DriverProvider>().updateDisplayName(name);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Perfil actualizado")));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final driver = context.watch<DriverProvider>().self;
    final intercom = context.watch<IntercomProvider>();
    final tripProvider = context.watch<TripProvider>();
    final allTrips = tripProvider.trips;
    final trips = allTrips.where((t) => t.driverId == driver?.id).toList();
    final activeTrip = trips.where((t) => t.status == "assigned").toList();
    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final isVisible = (driver?.status ?? "").toLowerCase().startsWith(
      "disponible",
    );
    final completed = driver == null
        ? 0
        : tripProvider.completedTrips(driverId: driver.id);
    final rejected = driver == null
        ? 0
        : tripProvider.rejectedTrips(driverId: driver.id);
    final acceptance = driver == null
        ? 0.0
        : tripProvider.acceptanceRate(driverId: driver.id);
    final revenue = driver == null
        ? 0.0
        : tripProvider.confirmedRevenue(driverId: driver.id);
    final avgFare = driver == null
        ? 0.0
        : tripProvider.averageFare(driverId: driver.id);
    final avgMiles = driver == null
        ? 0.0
        : tripProvider.averageDistanceMiles(driverId: driver.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Perfil de conductor",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                CustomInput(
                  controller: _nameCtrl,
                  hint: "Nombre de perfil",
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 10),
                Text("ID: ${auth.user?.id ?? '-'}"),
                const SizedBox(height: 6),
                Text("Estado actual: ${driver?.status ?? 'Offline'}"),
                const SizedBox(height: 6),
                Text(
                  "Intercom: ${intercom.isPublic ? 'Canal 1 publico' : 'Canal 2 privado'}",
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Visibilidad en mapa",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isVisible
                            ? "VISIBLE: recibiendo viajes"
                            : "INVISIBLE: sin nuevas asignaciones",
                        style: TextStyle(
                          color: isVisible
                              ? const Color(0xFF6CFFC0)
                              : const Color(0xFFFF97A2),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch.adaptive(
                  value: isVisible,
                  activeThumbColor: const Color(0xFF2FEA8A),
                  activeTrackColor: const Color(0x6636F8A0),
                  onChanged: (_) {
                    final next = isVisible
                        ? "No disponible (Invisible)"
                        : "Disponible (Visible)";
                    context.read<DriverProvider>().setOperationalStatus(next);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Viajes",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text("Total asignados: ${trips.length}"),
                const SizedBox(height: 6),
                Text("Pendientes por responder: ${activeTrip.length}"),
                const SizedBox(height: 10),
                if (trips.isEmpty)
                  const Text("No hay viajes en este momento")
                else
                  ...trips
                      .take(3)
                      .map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TripLine(trip: trip),
                        ),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Ganancias y rendimiento",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text("Ganancia confirmada: ${usd(revenue)}"),
                const SizedBox(height: 6),
                Text(
                  "Completados: $completed - Rechazados: $rejected - Aceptacion: ${percent(acceptance)}",
                ),
                const SizedBox(height: 6),
                Text("Promedio: ${usd(avgFare)} - ${milesText(avgMiles)}"),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tema de mapa",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SegmentedButton<MapThemeMode>(
                  segments: const [
                    ButtonSegment<MapThemeMode>(
                      value: MapThemeMode.flow,
                      icon: Icon(Icons.map_rounded),
                      label: Text("AtoB Flow"),
                    ),
                    ButtonSegment<MapThemeMode>(
                      value: MapThemeMode.dark,
                      icon: Icon(Icons.nights_stay_rounded),
                      label: Text("Modo oscuro"),
                    ),
                    ButtonSegment<MapThemeMode>(
                      value: MapThemeMode.satellite,
                      icon: Icon(Icons.satellite_alt_rounded),
                      label: Text("Satelital"),
                    ),
                  ],
                  selected: {mapTheme},
                  onSelectionChanged: (s) =>
                      context.read<MapUiProvider>().setThemeMode(s.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CustomButton(label: "Guardar perfil", onPressed: _saveProfile),
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Intercom canal publico",
          onPressed: () =>
              context.read<IntercomProvider>().setMode(private: false),
        ),
        if (driver?.currentTripId != null) ...[
          const SizedBox(height: 10),
          CustomButton(
            inverted: true,
            label: "Limpiar viaje asignado",
            onPressed: () => context.read<DriverProvider>().clearAssignedTrip(),
          ),
        ],
        if (intercom.isTransmitting) ...[
          const SizedBox(height: 10),
          CustomButton(
            inverted: true,
            label: "Detener transmision",
            onPressed: () => context.read<IntercomProvider>().releasePtt(),
          ),
        ],
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Cerrar sesion",
          onPressed: () async {
            await context.read<IntercomProvider>().releasePtt();
            if (!context.mounted) return;
            context.read<DriverProvider>().disconnect();
            context.read<AuthProvider>().logout();
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
          },
        ),
      ],
    );
  }
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2BFFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "${trip.origin} -> ${trip.destination}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trip.status.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
