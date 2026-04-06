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
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _loop;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _barOpacity;
  late final Animation<double> _shimmer;
  late final Animation<double> _haloPulse;

  String _phase = "";

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _barOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _loop, curve: Curves.easeInOut),
    );
    _haloPulse = Tween<double>(begin: 0.90, end: 1.08).animate(
      CurvedAnimation(parent: _loop, curve: Curves.easeInOut),
    );

    _entrance.forward();
    Future<void>.delayed(const Duration(milliseconds: 1400), _bootstrapSession);
  }

  void _setPhase(String phase) {
    if (!mounted) return;
    setState(() => _phase = phase);
  }

  Future<void> _bootstrapSession() async {
    _setPhase("Connecting...");
    final auth = context.read<AuthProvider>();
    final tripProvider = context.read<TripProvider>();
    final intercomProvider = context.read<IntercomProvider>();
    final chatProvider = context.read<ChatProvider>();
    final adminProvider = context.read<AdminProvider>();
    final driverProvider = context.read<DriverProvider>();
    final mapUiProvider = context.read<MapUiProvider>();

    _setPhase("Loading session...");
    await auth.ensureLoaded();
    if (!mounted) return;

    final user = auth.user;
    if (user == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }

    _setPhase(user.role == UserRole.admin
        ? "Setting up admin..."
        : "Setting up driver...");

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
      _setPhase("Loading admin panel...");
      adminProvider.connectAdmin(id: user.id, name: user.name);
      await auth.reconcileAuthorizedDriverState();
      await auth.refreshAdminPanelState();
      if (!mounted) return;
      intercomProvider.setMode(private: false);
      Navigator.of(context).pushReplacementNamed(AppRoutes.adminHome);
      return;
    }

    _setPhase("Connecting driver...");
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
    _setPhase("Loading trips...");
    await tripProvider.refreshFromServer(driverId: resolvedId);
    if (!mounted) return;
    intercomProvider.setMode(private: false);
    Navigator.of(context).pushReplacementNamed(AppRoutes.driverHome);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShell(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entrance, _loop]),
            builder: (context, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: _haloPulse.value,
                            child: Container(
                              width: 190,
                              height: 190,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x303DDC97),
                                    Color(0x143DDC97),
                                    Color(0x083DDC97),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.4, 0.7, 1.0],
                                ),
                              ),
                            ),
                          ),
                          const AtoBLogo(size: 108, showWordmark: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: _textOpacity.value,
                    child: const Column(
                      children: [
                        Text(
                          "AtoB",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "D I S P A T C H",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Opacity(
                    opacity: _barOpacity.value,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 200,
                          height: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Stack(
                              children: [
                                Container(color: const Color(0x14FFFFFF)),
                                Positioned.fill(
                                  child: ShaderMask(
                                    shaderCallback: (rect) {
                                      return LinearGradient(
                                        begin: Alignment(
                                          _shimmer.value - 1,
                                          0,
                                        ),
                                        end: Alignment(_shimmer.value, 0),
                                        colors: const [
                                          Colors.transparent,
                                          Color(0xFF3DDC97),
                                          Color(0xFF42D0FF),
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.35, 0.65, 1.0],
                                      ).createShader(rect);
                                    },
                                    blendMode: BlendMode.srcIn,
                                    child: Container(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _phase,
                            key: ValueKey(_phase),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
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
