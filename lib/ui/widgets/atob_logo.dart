import "package:flutter/material.dart";

class AtoBLogo extends StatelessWidget {
  const AtoBLogo({super.key, this.size = 86, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: [
            BoxShadow(
              color: const Color(0x3300C8FF),
              blurRadius: size * 0.18,
              spreadRadius: size * 0.01,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.asset(
            "assets/branding/atob_app_icon.png",
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 12),
        Text(
          "AtoB",
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            shadows: const [
              Shadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        Text(
          "Dispatch",
          style: TextStyle(
            color: Colors.white70,
            fontSize: size * 0.14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}
