import "package:flutter/material.dart";

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050505), Color(0xFF090909), Color(0xFF111111)],
          stops: [0.08, 0.5, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -160,
            right: -80,
            child: _BlurGlow(size: 300, color: const Color(0x1FFFFFFF)),
          ),
          Positioned(
            left: -100,
            bottom: -120,
            child: _BlurGlow(size: 260, color: const Color(0x183DDC97)),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _BlurGlow extends StatelessWidget {
  const _BlurGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 100, spreadRadius: 14),
          ],
        ),
      ),
    );
  }
}
