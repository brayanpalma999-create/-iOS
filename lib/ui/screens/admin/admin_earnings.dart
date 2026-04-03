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
    final startOfToday = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final settledTrips = trips
        .where((trip) => tripProvider.countsTowardConfirmedEarnings(trip))
        .toList();
    final pendingAdminBalance = settledTrips.fold<double>(
      0,
      (sum, trip) => sum + tripProvider.serviceFeeForTrip(trip),
    );
    final todayAdminFee = settledTrips
        .where((trip) => !trip.createdAt.isBefore(startOfToday))
        .fold<double>(
          0,
          (sum, trip) => sum + tripProvider.serviceFeeForTrip(trip),
        );
    final thisWeekAdminFee = settledTrips
        .where((trip) => !trip.createdAt.isBefore(weekStart))
        .fold<double>(
          0,
          (sum, trip) => sum + tripProvider.serviceFeeForTrip(trip),
        );
    final grossCollected = settledTrips.fold<double>(
      0,
      (sum, trip) => sum + trip.fareUsd,
    );
    final completedTrips = settledTrips.length;
    final connectedDrivers = drivers.where((driver) => driver.isOnline).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _HeroCard(
          title: t(es: "Ganancias", en: "Earnings"),
          subtitle: t(
            es: "El admin liquida 25% por viaje y el driver conserva 75%.",
            en: "Admin settles 25% per trip while the driver keeps 75%.",
          ),
        ),
        const SizedBox(height: 14),
        _MetricGrid(
          children: [
            _MetricCard(
              label: t(
                es: "Balance pendiente admin",
                en: "Admin pending balance",
              ),
              value: usd(pendingAdminBalance),
              note: context.isEnglish
                  ? "25% of $completedTrips recorded trips"
                  : "25% de $completedTrips viajes registrados",
            ),
            _MetricCard(
              label: t(es: "Hoy", en: "Today"),
              value: usd(todayAdminFee),
              note: t(
                es: "Comision generada hoy",
                en: "Commission generated today",
              ),
            ),
            _MetricCard(
              label: t(es: "Esta semana", en: "This week"),
              value: usd(thisWeekAdminFee),
              note: t(
                es: "Service fee semanal",
                en: "Weekly service fee",
              ),
            ),
            _MetricCard(
              label: t(es: "Service fee acumulado", en: "Accumulated service fee"),
              value: usd(pendingAdminBalance),
              note: context.isEnglish
                  ? "Drivers collected ${usd(grossCollected)}"
                  : "Drivers cobraron ${usd(grossCollected)}",
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EmptyCard(
          text: context.isEnglish
              ? "$connectedDrivers drivers online. Pending admin balance matches accumulated fee until weekly settlement is marked."
              : "$connectedDrivers drivers online. El balance pendiente coincide con el service fee acumulado hasta registrar la liquidacion semanal.",
        ),
        const SizedBox(height: 16),
        Text(
          t(es: "Actividad reciente", en: "Recent activity"),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (settledTrips.isEmpty)
          _EmptyCard(
            text: t(
              es: "Aun no hay viajes para mostrar",
              en: "There are no trips to show yet",
            ),
          )
        else
          ...settledTrips
              .take(6)
              .map(
                (trip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TripFinanceLine(
                    title: "${trip.origin} -> ${trip.destination}",
                    trailing: usd(tripProvider.serviceFeeForTrip(trip)),
                    subtitle:
                        "${context.tripStatus(trip.status)} - ${milesText(trip.distanceMiles)} • ${t(es: "Driver", en: "Driver")} ${usd(tripProvider.driverNetForTrip(trip))} • ${t(es: "Total", en: "Total")} ${usd(trip.fareUsd)}",
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
