import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../routes.dart";
import "../../models/user_model.dart";
import "../../providers/admin_provider.dart";
import "../../providers/auth_provider.dart";
import "../../providers/chat_provider.dart";
import "../../providers/driver_provider.dart";
import "../../providers/intercom_provider.dart";
import "../../providers/map_ui_provider.dart";
import "../../providers/trip_provider.dart";
import "../widgets/app_shell.dart";
import "../widgets/atob_logo.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _markScale;
  late final Animation<double> _arrowSlide;
  late final Animation<double> _arrowGlow;
  late final Animation<double> _haloPulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    )..repeat();

    _markScale = Tween<double>(
      begin: 0.96,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _arrowSlide = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _arrowGlow = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _haloPulse = Tween<double>(
      begin: 0.88,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future<void>.delayed(const Duration(milliseconds: 2050), _bootstrapSession);
  }

  Future<void> _bootstrapSession() async {
    final auth = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final intercomProvider = context.read<IntercomProvider>();
    final chatProvider = context.read<ChatProvider>();
    final adminProvider = context.read<AdminProvider>();
    final driverProvider = context.read<DriverProvider>();
    final mapUiProvider = context.read<MapUiProvider>();

    await auth.ensureLoaded();
    if (!mounted) return;

    final user = auth.user;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    mapUiProvider.setThemeModeFromName(user.mapThemeMode);
    chatProvider.setIdentity(
      userId: user.id,
      name: user.name,
      isAdmin: user.role == UserRole.admin,
    );
    intercomProvider.setIdentity(
      userId: user.id,
      isAdmin: user.role == UserRole.admin,
      name: user.name,
    );

    if (user.role == UserRole.admin) {
      adminProvider.connectAdmin(id: user.id, name: user.name);
      await auth.refreshAdminPanelState();
      if (!mounted) return;
      intercomProvider.setMode(private: false);
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
      return;
    }

    await driverProvider.connectDriver(
      id: user.id,
      name: user.name,
      email: user.email,
      phoneNumber: user.phoneNumber,
      address: user.address,
      governmentId: user.governmentId,
      avatarPath: user.avatarPath,
      languageCode: user.languageCode,
      mapThemeMode: user.mapThemeMode,
      vehicleMake: user.vehicleMake,
      vehicleModel: user.vehicleModel,
      vehicleColor: user.vehicleColor,
      vehiclePlate: user.vehiclePlate,
      vehicleYear: user.vehicleYear,
    );
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
    await tripProvider.refreshFromServer(driverId: resolvedId);
    if (!mounted) return;
    intercomProvider.setMode(private: false);
    Navigator.of(context).pushReplacementNamed(AppRoutes.driverHome);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShell(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _haloPulse.value,
                        child: Container(
                          width: 158,
                          height: 158,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x243DDC97),
                                Color(0x103DDC97),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: _markScale.value,
                        child: const AtoBLogo(size: 118, showWordmark: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: 176,
                    height: 22,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white10,
                          ),
                        ),
                        Positioned(
                          left: 128 * _arrowSlide.value,
                          child: Opacity(
                            opacity: _arrowGlow.value.clamp(0.0, 1.0),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF42D0FF),
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Loading live dispatch",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
