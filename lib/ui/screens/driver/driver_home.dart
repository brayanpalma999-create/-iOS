import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/driver_provider.dart";
import "../../../utils/app_text.dart";
import "../../widgets/app_shell.dart";
import "../../widgets/help_sheet.dart";
import "driver_earnings.dart";
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
    DriverEarnings(),
    DriverSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final self = context.watch<DriverProvider>().self;
    final title = switch (_index) {
      1 => t(es: "Ruta", en: "Route"),
      2 => t(es: "Intercom", en: "Intercom"),
      3 => t(es: "Ganancias", en: "Earnings"),
      4 => t(es: "Cuenta", en: "Account"),
      _ => t(es: "Mapa", en: "Map"),
    };
    final helpTopic = switch (_index) {
      1 => AtoBHelpTopic.driverRoute,
      2 => AtoBHelpTopic.intercom,
      3 => AtoBHelpTopic.driverEarnings,
      4 => AtoBHelpTopic.account,
      _ => AtoBHelpTopic.driverMap,
    };
    return Scaffold(
      body: AppShell(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () =>
                        showAtoBHelpSheet(context, topic: helpTopic),
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                  const SizedBox(width: 8),
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
                      self?.status ?? t(es: "Sin conexion", en: "Offline"),
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
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.map_rounded),
              label: t(es: "Mapa", en: "Map"),
            ),
            NavigationDestination(
              icon: const Icon(Icons.route_rounded),
              label: t(es: "Ruta", en: "Route"),
            ),
            NavigationDestination(
              icon: const Icon(Icons.mic_rounded),
              label: t(es: "Intercom", en: "Intercom"),
            ),
            NavigationDestination(
              icon: const Icon(Icons.payments_rounded),
              label: t(es: "Ganancias", en: "Earnings"),
            ),
            NavigationDestination(
              icon: CircleAvatar(
                radius: 13,
                backgroundColor: Color(0x1F3DDC97),
                child: Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Color(0xFF8DF5C6),
                ),
              ),
              label: t(es: "Cuenta", en: "Account"),
            ),
          ],
        ),
      ),
    );
  }
}
