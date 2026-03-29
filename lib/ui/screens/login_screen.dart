import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/user_model.dart";
import "../../providers/admin_provider.dart";
import "../../providers/auth_provider.dart";
import "../../providers/driver_provider.dart";
import "../../providers/intercom_provider.dart";
import "../../routes.dart";
import "../../utils/constants.dart";
import "../widgets/app_shell.dart";
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.login(name: name, role: _role, password: _passwordCtrl.text.trim());

    final user = auth.user!;
    context.read<IntercomProvider>().setIdentity(
      userId: user.id,
      isAdmin: _role == UserRole.admin,
      name: user.name,
    );
    if (_role == UserRole.admin) {
      context.read<AdminProvider>().connectAdmin(id: user.id, name: user.name);
      context.read<IntercomProvider>().setMode(private: false);
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
    } else {
      context.read<DriverProvider>().connectDriver(
        id: user.id,
        name: user.name,
      );
      context.read<IntercomProvider>().setMode(private: false);
      Navigator.of(context).pushReplacementNamed(AppRoutes.driverHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShell(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AtoB",
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Movilidad y despacho en tiempo real",
                        style: TextStyle(
                          color: AppConstants.muted,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x30FFFFFF)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppConstants.accent,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Acceso seguro para operaciones Admin y Driver",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomInput(
                        controller: _nameCtrl,
                        hint: "Nombre",
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      CustomInput(
                        controller: _passwordCtrl,
                        hint: "Contrasena",
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment<UserRole>(
                              value: UserRole.admin,
                              icon: Icon(Icons.admin_panel_settings_rounded),
                              label: Text("ADMIN"),
                            ),
                            ButtonSegment<UserRole>(
                              value: UserRole.driver,
                              icon: Icon(Icons.local_taxi_rounded),
                              label: Text("DRIVER"),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (s) =>
                              setState(() => _role = s.first),
                        ),
                      ),
                      const SizedBox(height: 18),
                      CustomButton(
                        label: _role == UserRole.admin
                            ? "Entrar como Admin"
                            : "Entrar como Driver",
                        onPressed: _login,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
