import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../models/operations_model.dart";
import "../../../providers/operations_provider.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";

class AdminOperationsMonitorPage extends StatefulWidget {
  const AdminOperationsMonitorPage({super.key});

  @override
  State<AdminOperationsMonitorPage> createState() =>
      _AdminOperationsMonitorPageState();
}

class _AdminOperationsMonitorPageState
    extends State<AdminOperationsMonitorPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OperationsProvider>().refresh();
    });
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      context.read<OperationsProvider>().refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final provider = context.watch<OperationsProvider>();
    final summary = provider.summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(t(es: "Monitor operativo", en: "Operations monitor")),
      ),
      body: summary == null && provider.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<OperationsProvider>().refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (summary == null)
                    _Panel(
                      child: Text(
                        provider.error ??
                            t(
                              es: "No se pudo cargar el monitor operativo.",
                              en: "The operations monitor could not be loaded.",
                            ),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  else ...[
                    if ((summary.system.warning ?? "").isNotEmpty) ...[
                      _Panel(
                        borderColor: const Color(0x46FFC857),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t(
                                es: "Alerta de persistencia",
                                en: "Persistence alert",
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFFFD771),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              summary.system.warning!,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricCard(
                          label: t(es: "Drivers online", en: "Drivers online"),
                          value: "${summary.counts.onlineDrivers}",
                        ),
                        _MetricCard(
                          label: t(es: "Rutas activas", en: "Active routes"),
                          value: "${summary.counts.activeTrips}",
                        ),
                        _MetricCard(
                          label: t(es: "Pendientes", en: "Pending"),
                          value: "${summary.counts.pendingActivations}",
                        ),
                        _MetricCard(
                          label: t(es: "Completados", en: "Completed"),
                          value: "${summary.counts.completedTrips}",
                        ),
                        _MetricCard(
                          label: t(es: "Soporte", en: "Support"),
                          value: "${summary.counts.supportTickets}",
                        ),
                        _MetricCard(
                          label: t(es: "Telemetria", en: "Telemetry"),
                          value: "${summary.counts.telemetryEvents}",
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(es: "Estado del sistema", en: "System health"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Badge(
                                text: summary.system.inviteEmailConfigured
                                    ? t(es: "Correo listo", en: "Email ready")
                                    : t(es: "Correo pendiente", en: "Email pending"),
                                good: summary.system.inviteEmailConfigured,
                              ),
                              _Badge(
                                text: summary.system.liveKitConfigured
                                    ? t(es: "Intercom listo", en: "Intercom ready")
                                    : t(es: "Intercom pendiente", en: "Intercom pending"),
                                good: summary.system.liveKitConfigured,
                              ),
                              _Badge(
                                text:
                                    "${t(es: "Persistencia", en: "Persistence")}: ${summary.system.persistenceMode}",
                                good: summary.system.isStorageHealthy,
                              ),
                              _Badge(
                                text: summary.system.pushConfigured
                                    ? t(es: "Push listo", en: "Push ready")
                                    : t(es: "Push pendiente", en: "Push pending"),
                                good: summary.system.pushConfigured,
                              ),
                              _Badge(
                                text: summary.system.sentryConfigured
                                    ? t(es: "Telemetry lista", en: "Telemetry ready")
                                    : t(es: "Telemetry local", en: "Local telemetry"),
                                good: summary.system.sentryConfigured,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      t(es: "Alertas recientes", en: "Recent alerts"),
                    ),
                    const SizedBox(height: 8),
                    if (summary.recentNotifications.isEmpty)
                      _Panel(
                        child: Text(
                          t(
                            es: "Aun no hay alertas recientes.",
                            en: "There are no recent alerts yet.",
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ...summary.recentNotifications.map(
                        (item) => _EventTile(
                          title: item.title,
                          body: item.message,
                          stamp: _stamp(item.createdAt),
                          color: item.status == "attention"
                              ? const Color(0xFFFFC857)
                              : const Color(0xFF72BBFF),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      t(es: "Actividad reciente", en: "Recent activity"),
                    ),
                    const SizedBox(height: 8),
                    ...summary.recentAudit.map(
                      (item) => _EventTile(
                        title: item.title,
                        body: item.message.isEmpty ? item.type : item.message,
                        stamp: _stamp(item.createdAt),
                        color: switch (item.severity) {
                          "error" => const Color(0xFFFF7C8C),
                          "warning" => const Color(0xFFFFC857),
                          _ => const Color(0xFF41D891),
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      t(es: "Soporte reciente", en: "Recent support"),
                    ),
                    const SizedBox(height: 8),
                    if (summary.recentSupport.isEmpty)
                      _Panel(
                        child: Text(
                          t(
                            es: "No hay tickets recientes.",
                            en: "There are no recent tickets.",
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ...summary.recentSupport.map(
                        (item) => _EventTile(
                          title: item.title,
                          body: "${item.userName} • ${item.priority} • ${item.status}",
                          stamp: _stamp(item.updatedAt),
                          color: item.status == "resolved"
                              ? const Color(0xFF41D891)
                              : const Color(0xFFFFC857),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      t(es: "Errores cliente", en: "Client errors"),
                    ),
                    const SizedBox(height: 8),
                    if (summary.recentTelemetry.isEmpty)
                      _Panel(
                        child: Text(
                          t(
                            es: "No hay errores recientes de cliente.",
                            en: "There are no recent client errors.",
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ...summary.recentTelemetry.map(
                        (item) => _EventTile(
                          title: item.title.isEmpty ? item.type : item.title,
                          body: item.message.isEmpty ? item.type : item.message,
                          stamp: _stamp(item.createdAt),
                          color: item.severity == "error"
                              ? const Color(0xFFFF7C8C)
                              : const Color(0xFF72BBFF),
                        ),
                      ),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      t(es: "Top drivers", en: "Top drivers"),
                    ),
                    const SizedBox(height: 8),
                    if (summary.driverPerformance.isEmpty)
                      _Panel(
                        child: Text(
                          t(
                            es: "Todavia no hay metricas suficientes.",
                            en: "There are not enough metrics yet.",
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      ...summary.driverPerformance.map(
                        (item) => _DriverPerformanceTile(item: item),
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  String _stamp(DateTime value) {
    return "${value.month.toString().padLeft(2, "0")}/${value.day.toString().padLeft(2, "0")} ${value.hour.toString().padLeft(2, "0")}:${value.minute.toString().padLeft(2, "0")}";
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.good});

  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? const Color(0xFF41D891) : const Color(0xFFFFC857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.title,
    required this.body,
    required this.stamp,
    required this.color,
  });

  final String title;
  final String body;
  final String stamp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              stamp,
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverPerformanceTile extends StatelessWidget {
  const _DriverPerformanceTile({required this.item});

  final DriverPerformanceModel item;

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayName.trim().isEmpty
                  ? compactPersonName(item.driverId)
                  : compactPersonName(item.displayName),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  "${t(es: "Viajes", en: "Trips")}: ${item.totalTrips}",
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  "${t(es: "Completados", en: "Completed")}: ${item.completedTrips}",
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  "${t(es: "Activos", en: "Active")}: ${item.activeTrips}",
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  "${t(es: "Bruto", en: "Gross")}: ${usd(item.grossRevenue)}",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.borderColor = const Color(0x22FFFFFF),
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
