import "package:flutter/material.dart";

import "../../utils/constants.dart";

class MapMarker extends StatefulWidget {
  const MapMarker({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  State<MapMarker> createState() => _MapMarkerState();
}

class _MapMarkerState extends State<MapMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.65, end: 1).animate(_pulse),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 120),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xF2111418),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.active
                    ? AppConstants.accent
                    : const Color(0x508B8B8B),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 14,
                  spreadRadius: 0.2,
                ),
              ],
            ),
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF121920),
              border: Border.all(
                color: widget.active
                    ? AppConstants.accent
                    : const Color(0xFF5F5F5F),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.active ? AppConstants.accent : Colors.white)
                      .withValues(alpha: 0.24),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.navigation_rounded,
              size: 16,
              color: widget.active ? AppConstants.accent : Colors.white70,
            ),
          ),
          Container(
            width: 2,
            height: 10,
            color: widget.active
                ? AppConstants.accent
                : const Color(0xFF737373),
          ),
        ],
      ),
    );
  }
}
