import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../providers/auth_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../utils/app_text.dart";
import "../../widgets/app_shell.dart";
import "../../widgets/help_sheet.dart";
import "admin_access.dart";
import "admin_assign_trip.dart";
import "admin_earnings.dart";
import "admin_intercom.dart";
import "admin_map.dart";
import "admin_settings.dart";

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  static const String _adminPanelIndexKey = "atob_admin_panel_index_v1";
  int _index = 0;

  final _tabs = const [
    AdminMap(),
    AdminAssignTrip(),
    AdminIntercom(),
    AdminEarnings(),
    AdminAccess(),
    AdminSettings(),
  ];

  @override
  void initState() {
    super.initState();
    _restoreAdminPanel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAdminPanelState();
    });
  }

  Future<void> _restoreAdminPanel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt(_adminPanelIndexKey) ?? 0;
    if (!mounted) return;
    setState(() => _index = savedIndex.clamp(0, _tabs.length - 1));
  }

  Future<void> _saveAdminPanelIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_adminPanelIndexKey, index);
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final online = context
        .watch<DriverProvider>()
        .drivers
        .where((d) => d.isOnline)
        .length;
    final title = switch (_index) {
      1 => t(es: "Centro de operaciones", en: "Operations center"),
      2 => t(es: "Intercom", en: "Intercom"),
      3 => t(es: "Ganancias", en: "Earnings"),
      4 => t(es: "Acceso", en: "Access"),
      5 => t(es: "Cuenta", en: "Account"),
      _ => t(es: "Mapa operativo", en: "Operations map"),
    };
    final helpTopic = switch (_index) {
      1 => AtoBHelpTopic.adminAssign,
      2 => AtoBHelpTopic.intercom,
      3 => AtoBHelpTopic.adminEarnings,
      4 => AtoBHelpTopic.account,
      5 => AtoBHelpTopic.account,
      _ => AtoBHelpTopic.adminMap,
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
                  if (_index <= 1)
                    _Pill(
                      icon: Icons.circle,
                      text: context.isEnglish
                          ? "$online online"
                          : "$online en linea",
                      color: Colors.greenAccent,
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: _tabs,
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
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 72,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(size: isSelected ? 22 : 21);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: isSelected ? 11.5 : 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              _saveAdminPanelIndex(i);
            },
            backgroundColor: Colors.transparent,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.map_rounded),
                label: t(es: "Mapa", en: "Map"),
              ),
              NavigationDestination(
                icon: const Icon(Icons.alt_route_rounded),
                label: t(es: "Asignar", en: "Assign"),
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
                icon: const Icon(Icons.badge_outlined),
                label: t(es: "Acceso", en: "Access"),
              ),
              NavigationDestination(
                icon: CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(0x1F3DDC97),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: Color(0xFF8DF5C6),
                  ),
                ),
                label: t(es: "Cuenta", en: "Account"),
              ),
            ],
          ),
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
