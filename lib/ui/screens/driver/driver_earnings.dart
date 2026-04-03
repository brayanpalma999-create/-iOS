import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";

class DriverEarnings extends StatelessWidget {
  const DriverEarnings({super.key});

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final driver = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();
    final driverId = driver?.id;
    final trips = driverId == null
        ? const []
        : tripProvider.trips
              .where((trip) => trip.driverId == driverId)
              .toList();

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final settledTrips = trips
        .where((trip) => tripProvider.countsTowardConfirmedEarnings(trip))
        .toList();
    final currentBalance = tripProvider.driverNetRevenue(
      driverId: driverId,
      confirmedOnly: true,
    );
    final todayDriverNet = settledTrips
        .where((trip) => !trip.createdAt.isBefore(startOfToday))
        .fold<double>(
          0,
          (sum, trip) => sum + tripProvider.driverNetForTrip(trip),
        );
    final thisWeek = settledTrips
        .where((trip) => !trip.createdAt.isBefore(weekStart))
        .fold<double>(
          0,
          (sum, trip) => sum + tripProvider.driverNetForTrip(trip),
        );
    final totalDriverNet = settledTrips.fold<double>(
      0,
      (sum, trip) => sum + tripProvider.driverNetForTrip(trip),
    );
    final pendingAdminFee = settledTrips.fold<double>(
      0,
      (sum, trip) => sum + tripProvider.serviceFeeForTrip(trip),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF142018), Color(0xFF0D1113)],
            ),
            border: Border.all(color: const Color(0x3C3DDC97)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(es: "Ganancias", en: "Earnings"),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                t(es: "Balance actual", en: "Current balance"),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                usd(currentBalance),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                driver == null
                    ? t(
                        es: "Conecta la cuenta para empezar a registrar viajes.",
                        en: "Connect the account to start registering trips.",
                      )
                    : t(
                        es: "Tu 75% queda aqui. El 25% restante se registra para el admin.",
                        en: "Your 75% stays here. The remaining 25% is tracked for admin.",
                      ),
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MiniCard(
              title: t(es: "Hoy", en: "Today"),
              value: usd(todayDriverNet),
              subtitle: context.isEnglish
                  ? "${tripProvider.completedTrips(driverId: driverId)} trips"
                  : "${tripProvider.completedTrips(driverId: driverId)} viajes",
            ),
            _MiniCard(
              title: t(es: "Esta semana", en: "This week"),
              value: usd(thisWeek),
              subtitle: t(es: "Ganancia neta", en: "Net earnings"),
            ),
            _MiniCard(
              title: t(es: "Total acumulado", en: "Lifetime total"),
              value: usd(totalDriverNet),
              subtitle: t(es: "75% del valor total", en: "75% of total fare"),
            ),
            _MiniCard(
              title: t(es: "Pendiente admin", en: "Admin pending"),
              value: usd(pendingAdminFee),
              subtitle: t(
                es: "25% acumulado por liquidar",
                en: "Accumulated 25% to settle",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t(es: "Ultimos movimientos", en: "Recent activity"),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (settledTrips.isEmpty)
          _EmptyBlock(
            text: t(
              es: "Todavia no hay movimientos en ganancias",
              en: "There is no earnings activity yet",
            ),
          )
        else
          ...settledTrips
              .take(6)
              .map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripMovement(trip: trip),
                ),
              ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 430 ? 182 : 160,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF101214),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripMovement extends StatelessWidget {
  const _TripMovement({required this.trip});

  final dynamic trip;

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.read<TripProvider>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x1F3DDC97),
            ),
            child: const Icon(Icons.payments_rounded, color: Color(0xFF8DF5C6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${trip.origin} -> ${trip.destination}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  "${context.tripStatus(trip.status)} - ${milesText(trip.distanceMiles)} • Admin ${usd(tripProvider.serviceFeeForTrip(trip))} • Total ${usd(trip.fareUsd)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            usd(tripProvider.driverNetForTrip(trip)),
            style: const TextStyle(
              color: Color(0xFF8DF5C6),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}
