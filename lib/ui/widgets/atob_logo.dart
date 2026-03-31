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
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x263DDC97),
                  const Color(0x123DDC97),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Image.asset(
            "assets/branding/atob_mark.png",
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
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
        Image.asset(
          "assets/branding/atob_wordmark.png",
          width: size * 2.8,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}
