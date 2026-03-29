import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../widgets/app_shell.dart";
import "driver_intercom.dart";
import "driver_map.dart";
import "driver_settings.dart";
import "driver_trip_screen.dart";

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _index = 0;

  final _tabs = const [
    DriverMap(),
    DriverTripScreen(),
    DriverIntercom(),
    DriverSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    final self = context.watch<DriverProvider>().self;
    return Scaffold(
      body: AppShell(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Conductor ${self?.name ?? ''}".trim(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFF171717),
                      border: Border.all(color: const Color(0x2EFFFFFF)),
                    ),
                    child: Text(
                      self?.status ?? "Offline",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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
              icon: Icon(Icons.route_rounded),
              label: "Viaje",
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
