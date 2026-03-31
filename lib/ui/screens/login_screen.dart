import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/user_model.dart";
import "../../providers/admin_provider.dart";
import "../../providers/auth_provider.dart";
import "../../providers/chat_provider.dart";
import "../../providers/driver_provider.dart";
import "../../providers/intercom_provider.dart";
import "../../providers/trip_provider.dart";
import "../../routes.dart";
import "../../utils/app_text.dart";
import "../../utils/constants.dart";
import "../widgets/app_shell.dart";
import "../widgets/atob_logo.dart";
import "../widgets/custom_button.dart";
import "../widgets/custom_input.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  UserRole _role = UserRole.admin;
  bool _adminVerified = false;
  bool _adminVerifying = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAdmin() async {
    if (_adminVerified || _adminVerifying) return;
    setState(() => _adminVerifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _adminVerifying = false;
      _adminVerified = true;
    });
  }

  Future<void> _login() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (_role == UserRole.admin && !_adminVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.txt(
              es: "Completa la verificacion de admin antes de entrar",
              en: "Complete admin verification before entering",
            ),
          ),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final intercomProvider = context.read<IntercomProvider>();
    final chatProvider = context.read<ChatProvider>();
    final adminProvider = context.read<AdminProvider>();
    final driverProvider = context.read<DriverProvider>();
    tripProvider.clearAll();
    auth.login(name: name, role: _role, password: _passwordCtrl.text.trim());

    final user = auth.user!;
    chatProvider.setIdentity(
      userId: user.id,
      name: user.name,
      isAdmin: _role == UserRole.admin,
    );
    intercomProvider.setIdentity(
      userId: user.id,
      isAdmin: _role == UserRole.admin,
      name: user.name,
    );
    if (_role == UserRole.admin) {
      adminProvider.connectAdmin(id: user.id, name: user.name);
      intercomProvider.setMode(private: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
    } else {
      await driverProvider.connectDriver(id: user.id, name: user.name);
      final resolvedId = driverProvider.self?.id ?? user.id;
      chatProvider.setIdentity(
        userId: resolvedId,
        name: user.name,
        isAdmin: false,
      );
      intercomProvider.setIdentity(
        userId: resolvedId,
        isAdmin: false,
        name: user.name,
      );
      if (!mounted) return;
      intercomProvider.setMode(private: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.driverHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: AppShell(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 34,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: AtoBLogo(size: 62, showWordmark: true),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  t(
                                    es: "Movilidad y despacho en tiempo real",
                                    en: "Real-time mobility and dispatch",
                                  ),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF171717),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0x28FFFFFF),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shield_outlined,
                                        size: 15,
                                        color: AppConstants.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        t(
                                          es: "Acceso seguro",
                                          en: "Secure access",
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<UserRole>(
                                  segments: const [
                                    ButtonSegment<UserRole>(
                                      value: UserRole.admin,
                                      icon: Icon(
                                        Icons.admin_panel_settings_rounded,
                                      ),
                                      label: Text("ADMIN"),
                                    ),
                                    ButtonSegment<UserRole>(
                                      value: UserRole.driver,
                                      icon: Icon(Icons.local_taxi_rounded),
                                      label: Text("DRIVER"),
                                    ),
                                  ],
                                  selected: {_role},
                                  onSelectionChanged: (s) => setState(() {
                                    _role = s.first;
                                    if (_role != UserRole.admin) {
                                      _adminVerified = false;
                                      _adminVerifying = false;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(height: 14),
                              CustomInput(
                                controller: _nameCtrl,
                                hint: t(es: "Nombre", en: "Name"),
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 10),
                              CustomInput(
                                controller: _passwordCtrl,
                                hint: t(es: "Contrasena", en: "Password"),
                                obscureText: true,
                                prefixIcon: Icons.lock_outline_rounded,
                              ),
                              if (_role == UserRole.admin) ...[
                                const SizedBox(height: 12),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121212),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _adminVerified
                                          ? const Color(0x703DDC97)
                                          : const Color(0x25FFFFFF),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _adminVerified
                                              ? const Color(0xFF3DDC97)
                                              : const Color(0xFF1C1C1C),
                                          border: Border.all(
                                            color: _adminVerified
                                                ? const Color(0xFF3DDC97)
                                                : Colors.white24,
                                          ),
                                        ),
                                        child: _adminVerifying
                                            ? const Padding(
                                                padding: EdgeInsets.all(5),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                _adminVerified
                                                    ? Icons.check_rounded
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 14,
                                                color: _adminVerified
                                                    ? Colors.black
                                                    : Colors.white70,
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          t(
                                            es: "Verificacion admin",
                                            en: "Admin verification",
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _verifyAdmin,
                                        child: Text(
                                          _adminVerified
                                              ? t(
                                                  es: "Verificado",
                                                  en: "Verified",
                                                )
                                              : _adminVerifying
                                              ? t(
                                                  es: "Verificando...",
                                                  en: "Verifying...",
                                                )
                                              : t(
                                                  es: "Verificar",
                                                  en: "Verify",
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              CustomButton(
                                label: _role == UserRole.admin
                                    ? t(
                                        es: "Entrar como Admin",
                                        en: "Enter as Admin",
                                      )
                                    : t(
                                        es: "Entrar como Driver",
                                        en: "Enter as Driver",
                                      ),
                                onPressed: _login,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
