import "package:flutter/material.dart";

import "../../utils/constants.dart";

class CustomButton extends StatefulWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.inverted = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? leading;
  final bool inverted;

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          height: 50,
          decoration: BoxDecoration(
            color: widget.inverted ? const Color(0xFF181818) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.inverted
                  ? const Color(0x33FFFFFF)
                  : const Color(0x19FFFFFF),
            ),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: (widget.inverted ? Colors.black : Colors.white)
                          .withValues(alpha: widget.inverted ? 0.35 : 0.18),
                      blurRadius: widget.inverted ? 10 : 16,
                      spreadRadius: 0.2,
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      color: widget.inverted ? Colors.white : Colors.black,
                      size: 18,
                    ),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.inverted ? AppConstants.text : Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
