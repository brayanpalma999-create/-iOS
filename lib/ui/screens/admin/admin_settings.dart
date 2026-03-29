import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/admin_provider.dart";
import "../../../providers/auth_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/intercom_provider.dart";
import "../../../providers/map_ui_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../routes.dart";
import "../../../services/socket_service.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _profileSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileSeeded) return;
    _profileSeeded = true;
    _nameCtrl.text = context.read<AuthProvider>().user?.name ?? "";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await context.read<IntercomProvider>().releasePtt();
    if (!mounted) return;
    context.read<AdminProvider>().disconnect();
    context.read<AuthProvider>().logout();
    context.read<DriverProvider>().disconnect();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _saveProfile() {
    final auth = context.read<AuthProvider>();
    final name = _nameCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (name.isNotEmpty) {
      auth.updateName(name);
    }

    var message = "Perfil actualizado";
    if (password.isNotEmpty) {
      final ok = auth.updatePassword(password);
      if (!ok) {
        message = "Contrasena muy corta (minimo 6 caracteres)";
      } else {
        _passCtrl.clear();
        message = "Perfil y contrasena guardados";
      }
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _reconnect() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final admin = context.read<AdminProvider>();
    admin.disconnect();
    admin.connectAdmin(
      id: user.id,
      name: _nameCtrl.text.trim().isEmpty ? user.name : _nameCtrl.text.trim(),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Conexion reiniciada")));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final drivers = context.watch<DriverProvider>().drivers;
    final online = drivers.where((d) => d.isOnline).length;
    final intercom = context.watch<IntercomProvider>();
    final tripProvider = context.watch<TripProvider>();
    final trips = tripProvider.trips;
    final tripCount = trips.length;
    final pendingTrips = trips.where((t) => t.status == "assigned").length;
    final revenue = tripProvider.estimatedRevenue();
    final completed = tripProvider.completedTrips();
    final rejected = tripProvider.rejectedTrips();
    final acceptance = tripProvider.acceptanceRate();
    final avgFare = tripProvider.averageFare();
    final avgMiles = tripProvider.averageDistanceMiles();
    final mapTheme = context.watch<MapUiProvider>().themeMode;
    final socketConnected = context.watch<SocketService>().isConnected;
    final passUpdated = auth.passwordUpdatedAt;

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
                  "Perfil de administrador",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                CustomInput(
                  controller: _nameCtrl,
                  hint: "Cambiar nombre",
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                CustomInput(
                  controller: _passCtrl,
                  hint: "Cambiar contrasena",
                  obscureText: true,
                  prefixIcon: Icons.password_rounded,
                ),
                const SizedBox(height: 10),
                Text(
                  "ID: ${auth.user?.id ?? '-'}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  "Contrasena: ${auth.hasPassword ? 'Configurada' : 'No configurada'}",
                  style: const TextStyle(color: Colors.white70),
                ),
                if (passUpdated != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Ultima actualizacion: ${passUpdated.toLocal()}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
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
                  "Centro operativo",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text("Drivers conectados: ${drivers.length}"),
                const SizedBox(height: 6),
                Text("Drivers online: $online"),
                const SizedBox(height: 6),
                Text("Viajes registrados: $tripCount"),
                const SizedBox(height: 6),
                Text(
                  "Socket: ${socketConnected ? 'Conectado' : 'Sin conexion'}",
                ),
                const SizedBox(height: 6),
                Text(
                  "Canal intercom: ${intercom.isPublic ? 'Canal 1 publico' : 'Canal 2 privado'}",
                ),
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
                  "Viajes y despacho",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text("Viajes pendientes: $pendingTrips"),
                const SizedBox(height: 6),
                Text("Ganancia estimada: ${usd(revenue)}"),
                const SizedBox(height: 6),
                Text(
                  "Completados: $completed • Rechazados: $rejected • Aceptacion: ${percent(acceptance)}",
                ),
                const SizedBox(height: 6),
                Text("Promedio: ${usd(avgFare)} • ${milesText(avgMiles)}"),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  const Text("No hay viajes registrados")
                else
                  ...trips
                      .take(3)
                      .map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alt_route_rounded,
                                size: 15,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${trip.origin} -> ${trip.destination}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trip.status,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
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
          label: "Recargar drivers",
          onPressed: () => context.read<AdminProvider>().refreshDrivers(),
        ),
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Reiniciar conexion",
          onPressed: _reconnect,
        ),
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Intercom en canal publico",
          onPressed: () =>
              context.read<IntercomProvider>().setMode(private: false),
        ),
        if (intercom.isTransmitting) ...[
          const SizedBox(height: 10),
          CustomButton(
            inverted: true,
            label: "Detener transmision activa",
            onPressed: () => context.read<IntercomProvider>().releasePtt(),
          ),
        ],
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Cerrar sesion",
          onPressed: _logout,
        ),
      ],
    );
  }
}
