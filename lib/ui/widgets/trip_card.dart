import "package:flutter/material.dart";

import "../../models/trip_model.dart";
import "../../utils/app_text.dart";
import "../../utils/helpers.dart";
import "../../utils/constants.dart";

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final color = switch (trip.status) {
      "accepted" => AppConstants.accent,
      "completed" => const Color(0xFF6EA8FF),
      "rejected" => Colors.redAccent,
      "assigned" => Colors.orangeAccent,
      _ => Colors.white70,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.isEnglish
                      ? "Trip #${trip.id.substring(0, trip.id.length > 5 ? 5 : trip.id.length)}"
                      : "Viaje #${trip.id.substring(0, trip.id.length > 5 ? 5 : trip.id.length)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${trip.origin} -> ${trip.destination}",
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.isEnglish
                  ? "Status: ${context.tripStatus(trip.status)}"
                  : "Estado: ${context.tripStatus(trip.status)}",
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (trip.distanceMiles > 0 || trip.fareUsd > 0) ...[
              const SizedBox(height: 6),
              Text(
                context.isEnglish
                    ? "Route: ${milesText(trip.distanceMiles)}  -  ${trip.durationMinutes.toStringAsFixed(0)} min"
                    : "Ruta: ${milesText(trip.distanceMiles)}  -  ${trip.durationMinutes.toStringAsFixed(0)} min",
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                context.isEnglish
                    ? "Estimated cost: ${usd(trip.fareUsd)}"
                    : "Costo estimado: ${usd(trip.fareUsd)}",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 4),
            Text(shortClock(trip.createdAt)),
          ],
        ),
      ),
    );
  }
}
