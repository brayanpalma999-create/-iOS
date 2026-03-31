import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";

class DriverTripScreen extends StatelessWidget {
  const DriverTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final self = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();
    final tripId = self?.currentTripId;
    final trip = tripId == null ? null : tripProvider.byId(tripId);

    if (trip == null ||
        (trip.status != "assigned" && trip.status != "accepted")) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Text("Sin viaje asignado"),
          ),
        ),
      );
    }

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
                  "Viaje recibido",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  "Origen: ${trip.origin}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text("Destino: ${trip.destination}"),
                const SizedBox(height: 8),
                Text("Estado: ${statusLabel(trip.status)}"),
                const SizedBox(height: 8),
                Text(
                  trip.distanceMiles > 0
                      ? "Distancia: ${milesText(trip.distanceMiles)}"
                      : "Distancia: pendiente",
                ),
                const SizedBox(height: 6),
                Text(
                  trip.durationMinutes > 0
                      ? "Duracion estimada: ${trip.durationMinutes.toStringAsFixed(0)} min"
                      : "Duracion estimada: pendiente",
                ),
                const SizedBox(height: 6),
                Text(
                  trip.fareUsd > 0
                      ? "Costo del viaje: ${usd(trip.fareUsd)}"
                      : "Costo del viaje: pendiente",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (trip.status == "assigned")
          CustomButton(
            label: "Iniciar ruta",
            leading: const Icon(Icons.play_arrow_rounded),
            onPressed: () =>
                context.read<DriverProvider>().startAssignedTrip(trip.id),
          ),
      ],
    );
  }
}
