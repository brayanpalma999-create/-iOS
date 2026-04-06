import "package:flutter/material.dart";
import "package:latlong2/latlong.dart";
import "package:provider/provider.dart";

import "../../../models/driver_model.dart";
import "../../../models/trip_model.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";
import "../../widgets/custom_button.dart";

class DriverTripScreen extends StatelessWidget {
  const DriverTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = Localizations.localeOf(context).languageCode == "en";
    final self = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();
    final tripId = self?.currentTripId;
    final trip = tripId == null ? null : tripProvider.byId(tripId);
    final canConfirmPickup = _canConfirmPickup(self, trip);
    final eta = trip == null || trip.durationMinutes <= 0
        ? null
        : DateTime.now().add(
            Duration(minutes: trip.durationMinutes.round()),
          );

    if (trip == null ||
        (trip.status != "assigned" &&
            trip.status != "accepted" &&
            trip.status != "picked_up")) {
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
                Text("Estado: ${context.statusLabel(trip.status)}"),
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
                  eta == null
                      ? (isEnglish
                            ? "Estimated arrival: pending"
                            : "Llegada estimada: pendiente")
                      : (isEnglish
                            ? "Estimated arrival: ${etaClock(eta)}"
                            : "Llegada estimada: ${etaClock(eta)}"),
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
            onPressed: () async =>
                context.read<DriverProvider>().startAssignedTrip(trip.id),
          ),
        if (trip.status == "accepted") ...[
          const SizedBox(height: 12),
          if (canConfirmPickup)
            CustomButton(
              label: "Cliente recogido",
              leading: const Icon(Icons.person_pin_circle_rounded),
              onPressed: () async =>
                  context.read<DriverProvider>().markPassengerPickedUp(trip.id),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  isEnglish
                      ? "Move closer to the pickup point before confirming the rider is onboard."
                      : "Acercate al punto de recogida para confirmar que el cliente ya abordo.",
                ),
              ),
            ),
        ],
        if (trip.status == "picked_up") ...[
          const SizedBox(height: 12),
          CustomButton(
            label: "Finalizar viaje",
            leading: const Icon(Icons.flag_circle_rounded),
            onPressed: () =>
                context.read<DriverProvider>().completeCurrentTrip(trip.id),
          ),
        ],
      ],
    );
  }

  bool _canConfirmPickup(DriverModel? self, TripModel? trip) {
    if (self == null || trip == null) return false;
    final origin = trip.originLocation;
    if (origin == null) return true;
    final here = LatLng(self.location.latitude, self.location.longitude);
    final pickup = LatLng(origin.latitude, origin.longitude);
    final meters = const Distance().as(LengthUnit.Meter, here, pickup);
    return meters <= 120;
  }
}
