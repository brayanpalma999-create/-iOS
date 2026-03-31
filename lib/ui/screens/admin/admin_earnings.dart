import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";

class AdminEarnings extends StatelessWidget {
  const AdminEarnings({super.key});

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final tripProvider = context.watch<TripProvider>();
    final drivers = context.watch<DriverProvider>().drivers;
    final trips = tripProvider.trips;
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart;

    final thisWeekRevenue = trips
        .where((trip) => trip.createdAt.isAfter(weekStart))
        .fold<double>(0, (sum, trip) => sum + trip.fareUsd);
    final lastWeekRevenue = trips
        .where(
          (trip) =>
              trip.createdAt.isAfter(lastWeekStart) &&
              trip.createdAt.isBefore(lastWeekEnd),
        )
        .fold<double>(0, (sum, trip) => sum + trip.fareUsd);
    final activeTrips = tripProvider.totalActiveTrips();
    final completedTrips = tripProvider.completedTrips();
    final connectedDrivers = drivers.where((driver) => driver.isOnline).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _HeroCard(
          title: t(es: "Ganancias", en: "Earnings"),
          subtitle: t(
            es: "Vista operativa de ingresos, flota y movimiento semanal.",
            en: "Operational view of revenue, fleet, and weekly movement.",
          ),
        ),
        const SizedBox(height: 14),
        _MetricGrid(
          children: [
            _MetricCard(
              label: t(es: "Balance actual", en: "Current balance"),
              value: usd(tripProvider.confirmedRevenue()),
              note: context.isEnglish
                  ? "$completedTrips completed trips"
                  : "$completedTrips viajes finalizados",
            ),
            _MetricCard(
              label: t(es: "Esta semana", en: "This week"),
              value: usd(thisWeekRevenue),
              note: t(es: "Actividad desde lunes", en: "Activity since Monday"),
            ),
            _MetricCard(
              label: t(es: "Semana pasada", en: "Last week"),
              value: usd(lastWeekRevenue),
              note: t(es: "Comparativo reciente", en: "Recent comparison"),
            ),
            _MetricCard(
              label: t(es: "Flota online", en: "Fleet online"),
              value: connectedDrivers.toString(),
              note: context.isEnglish
                  ? "$activeTrips active routes"
                  : "$activeTrips rutas activas",
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t(es: "Actividad reciente", en: "Recent activity"),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (trips.isEmpty)
          _EmptyCard(
            text: t(
              es: "Aun no hay viajes para mostrar",
              en: "There are no trips to show yet",
            ),
          )
        else
          ...trips
              .take(6)
              .map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripFinanceLine(
                    title: "${trip.origin} -> ${trip.destination}",
                    trailing: usd(trip.fareUsd),
                    subtitle:
                        "${context.tripStatus(trip.status)} - ${milesText(trip.distanceMiles)}",
                  ),
                ),
              ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF18211D), Color(0xFF0F1213)],
        ),
        border: Border.all(color: const Color(0x3D3DDC97)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width > 430 ? 182 : 160,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111315),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x28FFFFFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripFinanceLine extends StatelessWidget {
  const _TripFinanceLine({
    required this.title,
    required this.trailing,
    required this.subtitle,
  });

  final String title;
  final String trailing;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

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
