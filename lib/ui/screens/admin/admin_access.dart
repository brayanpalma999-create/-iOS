import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "../../../providers/auth_provider.dart";
import "../../../utils/app_text.dart";
import "../../widgets/custom_button.dart";
import "../../widgets/custom_input.dart";

class AdminAccess extends StatefulWidget {
  const AdminAccess({super.key});

  @override
  State<AdminAccess> createState() => _AdminAccessState();
}

class _AdminAccessState extends State<AdminAccess> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _governmentIdCtrl = TextEditingController();
  final _accessCodeCtrl = TextEditingController();
  String? _editingId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshAuthorizedDrivers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _governmentIdCtrl.dispose();
    _accessCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        (_editingId == null && _accessCodeCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              es: _editingId == null
                  ? "Nombre legal, correo y contrasena de acceso son obligatorios"
                  : "Nombre legal y correo son obligatorios",
              en: _editingId == null
                  ? "Legal name, email, and access password are required"
                  : "Legal name and email are required",
            ),
          ),
        ),
      );
      return;
    }

    final result = await context.read<AuthProvider>().saveAuthorizedDriver(
      id: _editingId,
      displayName: _nameCtrl.text,
      email: _emailCtrl.text,
      phoneNumber: _phoneCtrl.text,
      governmentId: _governmentIdCtrl.text,
      accessCode: _accessCodeCtrl.text,
    );
    if (!mounted) return;
    _clear();

    if (!result.inviteEmailSent &&
        !result.inviteQueued &&
        !result.inviteSkipped &&
        (result.activationUrl ?? "").isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              es: "Acceso guardado, pero el correo no salio. Usa el enlace de activacion.",
              en: "Access saved, but the email was not sent. Use the activation link.",
            ),
          ),
        ),
      );
      await _showActivationFallback(
        activationUrl: result.activationUrl!,
        inviteError: result.inviteError,
      );
      return;
    }

    final message = result.inviteEmailSent
        ? t(
            es: "Acceso del conductor guardado y correo enviado al instante",
            en: "Driver access saved and email sent instantly",
          )
        : result.inviteQueued
        ? t(
            es: "Acceso guardado. El correo de activacion ya va en camino.",
            en: "Access saved. The activation email is already on the way.",
          )
        : result.inviteSkipped
        ? t(
            es: "Acceso actualizado. Esta cuenta ya tenia su invitacion enviada.",
            en: "Access updated. This account had already received its invitation.",
          )
        : t(
            es: "Acceso del conductor guardado",
            en: "Driver access saved",
          );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showActivationFallback({
    required String activationUrl,
    String? inviteError,
  }) async {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101214),
          title: Text(t(es: "Activacion manual", en: "Manual activation")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  es: "El servidor guardo el acceso, pero no pudo enviar el correo. Copia este enlace y abrelo en el dispositivo del driver para activar la cuenta.",
                  en: "The server saved the access, but it could not send the email. Copy this link and open it on the driver's device to activate the account.",
                ),
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 12),
              SelectableText(
                activationUrl,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if ((inviteError ?? "").isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  inviteError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFFB3BA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: activationUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t(es: "Enlace copiado", en: "Link copied"),
                    ),
                  ),
                );
              },
              child: Text(t(es: "Copiar", en: "Copy")),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(t(es: "Cerrar", en: "Close")),
            ),
          ],
        );
      },
    );
  }

  void _clear() {
    setState(() {
      _editingId = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _governmentIdCtrl.clear();
      _accessCodeCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final auth = context.watch<AuthProvider>();
    final drivers = auth.authorizedDrivers;
    final authorizedCount = drivers.where((profile) => profile.isActive).length;
    final activeValidCount = drivers
        .where((profile) => profile.isActive && profile.isActivated)
        .length;
    final pendingCount = drivers.where((profile) => profile.activationPending).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF101214),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(es: "Otorgar acceso", en: "Grant access"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  es: "La invitacion del driver se crea de forma manual y privada. Desde aqui defines correo, datos base e ingreso por contrasena.",
                  en: "Driver invitations are created manually and privately. From here you define email, base data, and password access.",
                ),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.8,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              CustomInput(
                controller: _nameCtrl,
                hint: t(es: "Nombre legal completo", en: "Full legal name"),
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 10),
              CustomInput(
                controller: _emailCtrl,
                hint: t(es: "Correo electronico", en: "Email"),
                prefixIcon: Icons.alternate_email_rounded,
              ),
              const SizedBox(height: 10),
              CustomInput(
                controller: _phoneCtrl,
                hint: t(es: "Telefono", en: "Phone"),
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 10),
              CustomInput(
                controller: _governmentIdCtrl,
                hint: t(es: "Identificacion", en: "Government ID"),
                prefixIcon: Icons.credit_card_outlined,
              ),
              const SizedBox(height: 10),
              CustomInput(
                controller: _accessCodeCtrl,
                hint: _editingId == null
                    ? t(es: "Contrasena de acceso", en: "Access password")
                    : t(
                        es: "Nueva contrasena (opcional)",
                        en: "New password (optional)",
                      ),
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              if (_editingId != null) ...[
                const SizedBox(height: 8),
                Text(
                  t(
                    es: "Si dejas este campo vacio, el acceso actual del driver se conserva tal como esta.",
                    en: "If you leave this field empty, the driver's current password stays unchanged.",
                  ),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              CustomButton(
                label: _editingId == null
                    ? t(es: "Guardar acceso", en: "Save access")
                    : t(es: "Actualizar acceso", en: "Update access"),
                onPressed: _save,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t(es: "Conductores autorizados", en: "Authorized drivers"),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 10),
        if (drivers.isEmpty)
          _InfoCard(
            text: t(
              es: "Todavia no has otorgado accesos. Los drivers solo podran entrar cuando les crees una invitacion activa desde aqui.",
              en: "You have not granted any access yet. Drivers will only be able to sign in after you create an active invitation here.",
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101214),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x22FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$authorizedCount",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t(
                              es: "conductores autorizados en acceso",
                              en: "authorized drivers in access",
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 34,
                      color: Color(0xFF72BBFF),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      label: t(
                        es: "$activeValidCount activos y vigentes",
                        en: "$activeValidCount active and valid",
                      ),
                      color: const Color(0xFF41D891),
                    ),
                    _StatusPill(
                      label: t(
                        es: "$pendingCount pendientes",
                        en: "$pendingCount pending",
                      ),
                      color: const Color(0xFFFFC857),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    es: "La lista completa de conductores vive en Cuenta > Operacion > Records. Aqui solo queda la mini base de datos con el total y el estado general.",
                    en: "The full driver list now lives in Account > Operation > Records. This panel keeps only the mini database with totals and overall status.",
                  ),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
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
