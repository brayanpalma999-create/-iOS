import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "admin_account_pages.dart";
import "admin_operations_monitor.dart";
import "../../../providers/admin_provider.dart";
import "../../../providers/auth_provider.dart";
import "../../../providers/chat_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/intercom_provider.dart";
import "../../../providers/operations_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../routes.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";
import "../../widgets/account_avatar.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";
import "../../widgets/help_sheet.dart";

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  Timer? _refreshTimer;

  Future<void> _logout(BuildContext context) async {
    await context.read<IntercomProvider>().releasePtt();
    if (!context.mounted) return;
    context.read<ChatProvider>().clearSession();
    context.read<AdminProvider>().disconnect();
    context.read<TripProvider>().clearAll();
    context.read<AuthProvider>().logout();
    context.read<DriverProvider>().disconnect();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
      context.read<AuthProvider>().warmAuthorizedDriverRecords();
      context.read<OperationsProvider>().refresh();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
      context.read<AuthProvider>().warmAuthorizedDriverRecords();
      context.read<OperationsProvider>().refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final tripProvider = context.watch<TripProvider>();
    final drivers = context.watch<DriverProvider>().drivers;
    final onlineDrivers = drivers.where((driver) => driver.isOnline).length;
    final validRecords = auth.authorizedDrivers
        .where((profile) => profile.isActive && profile.isActivated)
        .length;
    final operations = context.watch<OperationsProvider>().summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _AccountHeaderCard(
          name: user?.name ?? t(es: "Cuenta", en: "Account"),
          subtitle: user?.email ?? "admin@atob.app",
          badge: "ADMIN",
          avatarPath: user?.avatarPath,
        ),
        const SizedBox(height: 14),
        _GroupCard(
          title: t(es: "Cuenta", en: "Account"),
          children: [
            _AccountTile(
              icon: Icons.person_outline_rounded,
              title: t(es: "Perfil", en: "Profile"),
              subtitle: t(
                es: "Foto, nombre legal, correo, telefono y direccion",
                en: "Photo, legal name, email, phone, and address",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminProfileSettingsPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.tune_rounded,
              title: t(es: "Preferencias", en: "Preferences"),
              subtitle: t(
                es: "Mapa, idioma y conexion de operacion",
                en: "Map, language, and operation settings",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminPreferencesSettingsPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.mail_outline_rounded,
              title: t(es: "Inbox", en: "Inbox"),
              subtitle: t(
                es: "Actualizaciones de viajes y flota",
                en: "Trip and fleet updates",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminInboxSettingsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GroupCard(
          title: t(es: "Operacion", en: "Operation"),
          children: [
            _AccountTile(
              icon: Icons.monitor_heart_outlined,
              title: t(es: "Monitor operativo", en: "Operations monitor"),
              subtitle: operations == null
                  ? t(
                      es: "Salud del backend, alertas y auditoria",
                      en: "Backend health, alerts, and audit",
                    )
                  : t(
                      es:
                          "${operations.counts.activeTrips} rutas activas • ${operations.counts.pendingActivations} pendientes",
                      en:
                          "${operations.counts.activeTrips} active routes • ${operations.counts.pendingActivations} pending",
                    ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminOperationsMonitorPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.groups_2_rounded,
              title: t(es: "Estado de flota", en: "Fleet status"),
              subtitle: context.isEnglish
                  ? "$onlineDrivers online out of ${drivers.length} connected"
                  : "$onlineDrivers online de ${drivers.length} conectados",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminFleetPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.analytics_outlined,
              title: t(es: "Resumen de viajes", en: "Trips overview"),
              subtitle:
                  "${tripProvider.totalTrips()} viajes - ${usd(tripProvider.estimatedRevenue())}",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _AdminTripsPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.fact_check_outlined,
              title: t(es: "Records", en: "Records"),
              subtitle: t(
                es: "$validRecords drivers activos con credenciales vigentes",
                en: "$validRecords active drivers with valid credentials",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminRecordsPage(),
                ),
              ),
            ),
            _AccountTile(
              icon: Icons.help_outline_rounded,
              title: t(es: "Ayuda", en: "Help"),
              subtitle: t(
                es: "FAQ y guia operativa rapida",
                en: "FAQ and quick operational guide",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const _AdminHelpPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GroupCard(
          title: t(es: "Seguridad", en: "Security"),
          children: [
            _AccountTile(
              icon: Icons.lock_outline_rounded,
              title: t(
                es: "Seguridad y contrasena",
                en: "Security and password",
              ),
              subtitle: t(
                es: "Contrasena y eliminacion de cuenta local",
                en: "Password and local account removal",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminSecuritySettingsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        CustomButton(
          inverted: true,
          label: t(es: "Cerrar sesion", en: "Log out"),
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}

class _AdminProfilePage extends StatefulWidget {
  const _AdminProfilePage();

  @override
  State<_AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<_AdminProfilePage> {
  final _displayNameCtrl = TextEditingController();
  final _legalNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final user = context.read<AuthProvider>().user;
    _displayNameCtrl.text = user?.name ?? "";
    _legalNameCtrl.text = user?.legalName ?? "";
    _emailCtrl.text = user?.email ?? "";
    _phoneCtrl.text = user?.phoneNumber ?? "";
    _addressCtrl.text = user?.address ?? "";
    _governmentIdCtrl.text = user?.governmentId ?? "";
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _legalNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _governmentIdCtrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AuthProvider>().updateProfile(
      displayName: _displayNameCtrl.text,
      legalName: _legalNameCtrl.text,
      email: _emailCtrl.text,
      phoneNumber: _phoneCtrl.text,
      address: _addressCtrl.text,
      governmentId: _governmentIdCtrl.text,
    );
    context.read<AdminProvider>().refreshDrivers();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Perfil actualizado")));
  }

  @override
  Widget build(BuildContext context) {
    return _AccountScaffold(
      title: "Profile",
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomInput(
            controller: _displayNameCtrl,
            hint: "Nombre visible",
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _legalNameCtrl,
            hint: "Nombre legal completo",
            prefixIcon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _emailCtrl,
            hint: "Correo electronico",
            prefixIcon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _phoneCtrl,
            hint: "Telefono",
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _addressCtrl,
            hint: "Direccion",
            prefixIcon: Icons.place_outlined,
          ),
          const SizedBox(height: 10),
          CustomInput(
            controller: _governmentIdCtrl,
            hint: "Identificacion",
            prefixIcon: Icons.credit_card_outlined,
          ),
          const SizedBox(height: 18),
          CustomButton(label: "Guardar cambios", onPressed: _save),
        ],
      ),
    );
  }
}

class _AdminFleetPage extends StatelessWidget {
  const _AdminFleetPage();

  @override
  Widget build(BuildContext context) {
    final drivers = context.watch<DriverProvider>().drivers;
    return _AccountScaffold(
      title: "Fleet status",
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HintCard(
            text:
                "Aqui ves solo drivers reales conectados en la sesion actual, con su estado operativo actual.",
          ),
          const SizedBox(height: 12),
          ...drivers.map(
            (driver) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101214),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x24FFFFFF)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0x1F3DDC97),
                      child: Text(
                        driver.name.characters.first.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8DF5C6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            driver.status,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: driver.isOnline
                            ? const Color(0x1A3DDC97)
                            : const Color(0x22FF667A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        driver.isOnline ? "ONLINE" : "OFFLINE",
                        style: TextStyle(
                          color: driver.isOnline
                              ? const Color(0xFF8DF5C6)
                              : const Color(0xFFFF92A2),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTripsPage extends StatelessWidget {
  const _AdminTripsPage();

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trips = tripProvider.trips;

    return _AccountScaffold(
      title: "Trips overview",
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsStrip(
            values: [
              _StatValue("Total", tripProvider.totalTrips().toString()),
              _StatValue("Activos", tripProvider.totalActiveTrips().toString()),
              _StatValue("Revenue", usd(tripProvider.estimatedRevenue())),
            ],
          ),
          const SizedBox(height: 12),
          ...trips.map(
            (trip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InboxCard(
                item: _InboxItem(
                  title: "${trip.origin} -> ${trip.destination}",
                  body:
                      "${statusLabel(trip.status)} - ${usd(trip.fareUsd)} - ${milesText(trip.distanceMiles)}",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHelpPage extends StatelessWidget {
  const _AdminHelpPage();

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    return _AccountScaffold(
      title: t(es: "Ayuda", en: "Help"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AccountTile(
            icon: Icons.map_outlined,
            title: t(es: "Ayuda del mapa", en: "Map help"),
            subtitle: t(
              es: "Ubicacion, flota, hotspots y centrado",
              en: "Location, fleet, hotspots, and centering",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.adminMap),
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.route_outlined,
            title: t(es: "Ayuda de asignaciones", en: "Assignments help"),
            subtitle: t(
              es: "Drivers elegibles, sugerencias y despacho",
              en: "Eligible drivers, suggestions, and dispatch",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.adminAssign),
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.settings_voice_outlined,
            title: t(es: "Ayuda del intercom", en: "Intercom help"),
            subtitle: t(
              es: "Canal publico, privado y PTT",
              en: "Public channel, private channel, and PTT",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.intercom),
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.payments_outlined,
            title: t(es: "Ayuda de ganancias", en: "Earnings help"),
            subtitle: t(
              es: "Balance, semanas y flota",
              en: "Balance, weeks, and fleet",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.adminEarnings),
          ),
          const SizedBox(height: 12),
          _AccountTile(
            icon: Icons.person_outline_rounded,
            title: t(es: "Ayuda de cuenta", en: "Account help"),
            subtitle: t(
              es: "Perfil, preferencias, inbox y seguridad",
              en: "Profile, preferences, inbox, and security",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.account),
          ),
          const SizedBox(height: 12),
          _HintCard(
            text: t(
              es: "Cada ayuda ahora esta separada por area para que el operador vea solo lo que le sirve en ese momento.",
              en: "Each help section is now separated by area so the operator only sees what is useful at that moment.",
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSecurityPage extends StatefulWidget {
  const _AdminSecurityPage();

  @override
  State<_AdminSecurityPage> createState() => _AdminSecurityPageState();
}

class _AdminSecurityPageState extends State<_AdminSecurityPage> {
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _savePassword() {
    final ok = context.read<AuthProvider>().updatePassword(_passwordCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? "Contrasena actualizada" : "Usa minimo 6 caracteres",
        ),
      ),
    );
    if (ok) {
      _passwordCtrl.clear();
    }
  }

  void _deleteLocalAccount() {
    context.read<AuthProvider>().logout();
    context.read<TripProvider>().clearAll();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return _AccountScaffold(
      title: "Security",
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomInput(
            controller: _passwordCtrl,
            hint: "Nueva contrasena",
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 14),
          CustomButton(label: "Guardar contrasena", onPressed: _savePassword),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1012),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x46FF667A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Eliminar esta cuenta",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFA6B3),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Esto limpia la sesion local del dispositivo y elimina el acceso actual.",
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 14),
                CustomButton(
                  label: "Eliminar cuenta local",
                  onPressed: _deleteLocalAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountScaffold extends StatelessWidget {
  const _AccountScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _AccountHeaderCard extends StatelessWidget {
  const _AccountHeaderCard({
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.avatarPath,
  });

  final String name;
  final String subtitle;
  final String badge;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final imageProvider = avatarFileProvider(avatarPath);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0x1F3DDC97),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(
                    Icons.person_rounded,
                    size: 32,
                    color: Color(0xFF8DF5C6),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.4,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 108),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1A3DDC97),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8DF5C6),
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
      onTap: onTap,
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _InboxItem {
  const _InboxItem({required this.title, required this.body});

  final String title;
  final String body;
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.item});

  final _InboxItem item;

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
          const Icon(Icons.notifications_none_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatValue {
  const _StatValue(this.label, this.value);

  final String label;
  final String value;
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.values});

  final List<_StatValue> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values
          .map(
            (item) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF101214),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
