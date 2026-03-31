import "dart:async";

import "package:flutter/material.dart";

import "../../routes.dart";
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

    Future<void>.delayed(const Duration(milliseconds: 2050), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    });
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
