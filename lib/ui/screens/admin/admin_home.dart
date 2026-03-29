import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../widgets/app_shell.dart";
import "admin_assign_trip.dart";
import "admin_intercom.dart";
import "admin_map.dart";
import "admin_settings.dart";

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _index = 0;

  final _tabs = const [
    AdminMap(),
    AdminAssignTrip(),
    AdminIntercom(),
    AdminSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    final online = context
        .watch<DriverProvider>()
        .drivers
        .where((d) => d.isOnline)
        .length;
    return Scaffold(
      body: AppShell(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Centro de Operaciones",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  _Pill(
                    icon: Icons.circle,
                    text: "$online online",
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _tabs[_index],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xD40D0D0D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x24FFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.map_rounded), label: "Mapa"),
            NavigationDestination(
              icon: Icon(Icons.alt_route_rounded),
              label: "Asignar",
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_rounded),
              label: "Intercom",
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: "Ajustes",
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFF171717),
        border: Border.all(color: const Color(0x2EFFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
