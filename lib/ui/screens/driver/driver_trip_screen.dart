import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../models/trip_model.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";

class DriverTripScreen extends StatelessWidget {
  const DriverTripScreen({super.key});

  TripModel? _findTrip(List<TripModel> trips, String? driverId) {
    if (driverId == null) return null;
    for (final trip in trips) {
      if (trip.driverId != driverId) continue;
      if (trip.status == "assigned" || trip.status == "accepted") {
        return trip;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final self = context.watch<DriverProvider>().self;
    final trip = _findTrip(context.watch<TripProvider>().trips, self?.id);

    if (trip == null) {
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
                Text("Estado: ${trip.status}"),
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
        CustomButton(
          label: "Aceptar",
          leading: const Icon(Icons.check_circle_outline),
          onPressed: () =>
              context.read<DriverProvider>().setTripDecision(trip.id, true),
        ),
        const SizedBox(height: 10),
        CustomButton(
          inverted: true,
          label: "Rechazar",
          leading: const Icon(Icons.close_rounded),
          onPressed: () =>
              context.read<DriverProvider>().setTripDecision(trip.id, false),
        ),
      ],
    );
  }
}
