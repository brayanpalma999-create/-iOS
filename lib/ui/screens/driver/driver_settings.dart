import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../../providers/auth_provider.dart";
import "../../../providers/chat_provider.dart";
import "../../../providers/driver_provider.dart";
import "../../../providers/intercom_provider.dart";
import "../../../providers/trip_provider.dart";
import "../../../routes.dart";
import "../../../utils/app_text.dart";
import "../../../utils/helpers.dart";
import "../../widgets/account_avatar.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";
import "../../widgets/help_sheet.dart";
import "../shared/support_center_page.dart";
import "driver_account_pages.dart";

class DriverSettings extends StatelessWidget {
  const DriverSettings({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<IntercomProvider>().releasePtt();
    if (!context.mounted) return;
    context.read<ChatProvider>().clearSession();
    context.read<DriverProvider>().disconnect();
    context.read<TripProvider>().clearAll();
    context.read<AuthProvider>().logout();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final auth = context.watch<AuthProvider>();
    final driver = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _HeaderCard(
          name: auth.user?.name ?? t(es: "Cuenta", en: "Account"),
          subtitle: auth.user?.email ?? "driver@atob.app",
          badge: driver?.status ?? t(es: "Driver", en: "Driver"),
          avatarPath: auth.user?.avatarPath,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: t(es: "Cuenta", en: "Account"),
          children: [
            _MenuTile(
              icon: Icons.person_outline_rounded,
              title: t(es: "Perfil", en: "Profile"),
              subtitle: t(
                es: "Datos personales y forma de contacto",
                en: "Personal details and contact information",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DriverProfileSettingsPage(),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.tune_rounded,
              title: t(es: "Preferencias", en: "Preferences"),
              subtitle: t(
                es: "Mapa, idioma y visibilidad operativa",
                en: "Map, language, and operational visibility",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DriverPreferencesSettingsPage(),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.mail_outline_rounded,
              title: t(es: "Inbox", en: "Inbox"),
              subtitle: t(
                es: "Resumen rapido de viajes y actividad reciente",
                en: "Quick overview of trips and recent activity",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DriverInboxSettingsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(es: "Operacion", en: "Operation"),
          children: [
            _MenuTile(
              icon: Icons.route_rounded,
              title: t(es: "Viajes", en: "Trips"),
              subtitle: context.isEnglish
                  ? "${tripProvider.totalTrips(driverId: driver?.id)} registered trips"
                  : "${tripProvider.totalTrips(driverId: driver?.id)} viajes registrados",
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _DriverTripsPage(),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.help_outline_rounded,
              title: t(es: "Ayuda", en: "Help"),
              subtitle: t(
                es: "Preguntas frecuentes y guia rapida",
                en: "Frequently asked questions and quick guide",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _DriverHelpPage(),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.support_agent_rounded,
              title: t(es: "Soporte e historial", en: "Support and history"),
              subtitle: t(
                es: "Casos, seguimiento y respuesta operativa",
                en: "Cases, tracking, and operational response",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SupportCenterPage(adminMode: false),
                ),
              ),
            ),
            _MenuTile(
              icon: Icons.lock_outline_rounded,
              title: t(es: "Seguridad", en: "Security"),
              subtitle: t(
                es: "Sesion, privacidad y eliminacion de cuenta local",
                en: "Session, privacy, and local account removal",
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DriverSecuritySettingsPage(),
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

class _DriverProfilePage extends StatefulWidget {
  const _DriverProfilePage();

  @override
  State<_DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<_DriverProfilePage> {
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
    context.read<DriverProvider>().updateDisplayName(_displayNameCtrl.text);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Perfil actualizado")));
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
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

class _DriverTripsPage extends StatelessWidget {
  const _DriverTripsPage();

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().self;
    final tripProvider = context.watch<TripProvider>();
    final trips = tripProvider.trips
        .where((trip) => trip.driverId == driver?.id)
        .toList();

    return _PageFrame(
      title: "Trips",
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: "Completados",
                  value: tripProvider
                      .completedTrips(driverId: driver?.id)
                      .toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: "Revenue",
                  value: usd(
                    tripProvider.confirmedRevenue(driverId: driver?.id),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...trips.map(
            (trip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NoticeCard(
                title: "${trip.origin} -> ${trip.destination}",
                body:
                    "${statusLabel(trip.status)} - ${milesText(trip.distanceMiles)} - ${usd(trip.fareUsd)}",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHelpPage extends StatelessWidget {
  const _DriverHelpPage();

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    return _PageFrame(
      title: t(es: "Ayuda", en: "Help"),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuTile(
            icon: Icons.map_outlined,
            title: t(es: "Ayuda del mapa", en: "Map help"),
            subtitle: t(
              es: "Ubicacion, centrado y visibilidad",
              en: "Location, centering, and visibility",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.driverMap),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.alt_route_rounded,
            title: t(es: "Ayuda de ruta", en: "Route help"),
            subtitle: t(
              es: "Asignacion, trazo y seguimiento",
              en: "Assignment, route line, and tracking",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.driverRoute),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.settings_voice_outlined,
            title: t(es: "Ayuda del intercom", en: "Intercom help"),
            subtitle: t(
              es: "Canales y uso del PTT",
              en: "Channels and PTT usage",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.intercom),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.payments_outlined,
            title: t(es: "Ayuda de ganancias", en: "Earnings help"),
            subtitle: t(
              es: "Balance y rendimiento personal",
              en: "Balance and personal performance",
            ),
            onTap: () =>
                showAtoBHelpSheet(context, topic: AtoBHelpTopic.driverEarnings),
          ),
          const SizedBox(height: 12),
          _MenuTile(
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
          _InfoCard(
            text: t(
              es: "La ayuda ahora esta separada por area para que el driver encuentre respuesta rapida sin navegar de mas.",
              en: "Help is now separated by area so the driver can find a quick answer without extra navigation.",
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverSecurityPage extends StatefulWidget {
  const _DriverSecurityPage();

  @override
  State<_DriverSecurityPage> createState() => _DriverSecurityPageState();
}

class _DriverSecurityPageState extends State<_DriverSecurityPage> {
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
    return _PageFrame(
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

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.title, required this.child});

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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
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
        border: Border.all(color: const Color(0x24FFFFFF)),
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
            constraints: const BoxConstraints(maxWidth: 118),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

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

class _MenuTile extends StatelessWidget {
  const _MenuTile({
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70)),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.title, required this.body});

  final String title;
  final String body;

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
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
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

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
