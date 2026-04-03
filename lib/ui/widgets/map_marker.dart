import "dart:math" as math;

import "package:flutter/material.dart";

import "../../utils/constants.dart";

class MapMarker extends StatefulWidget {
  const MapMarker({
    super.key,
    required this.label,
    required this.active,
    this.carMode = false,
    this.headingDegrees = 0,
  });

  final String label;
  final bool active;
  final bool carMode;
  final double headingDegrees;

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
      child: SizedBox(
        width: 86,
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 82),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xF2111418),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: widget.active
                      ? AppConstants.accent
                      : const Color(0x508B8B8B),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 12,
                    spreadRadius: 0.2,
                  ),
                ],
              ),
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 8.9,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(height: 1),
            widget.carMode ? _carBadge() : _navBadge(),
            Container(
              width: 2,
              height: 5,
              color: widget.active
                  ? AppConstants.accent
                  : const Color(0xFF737373),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBadge() {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF10161C),
        border: Border.all(
          color: widget.active ? AppConstants.accent : const Color(0xFF5F5F5F),
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
      child: const Icon(
        Icons.navigation_rounded,
        size: 14,
        color: Colors.white70,
      ),
    );
  }

  Widget _carBadge() {
    final accent = widget.active ? const Color(0xFF4EA6FF) : Colors.white70;
    final deepAccent = widget.active
        ? const Color(0xFF1D6FE2)
        : Colors.white54;
    return Transform.rotate(
      angle: widget.headingDegrees * math.pi / 180,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 2,
              child: Container(
                width: 14,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    spreadRadius: 0.4,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xF3DFF4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              bottom: 3,
              child: Row(
                children: [
                  _wheel(),
                  const SizedBox(width: 6.5),
                  _wheel(),
                ],
              ),
            ),
            Container(
              width: 16,
              height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.98),
                    deepAccent.withValues(alpha: 0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.12),
                    blurRadius: 4,
                    spreadRadius: 0.4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 4,
                    child: Container(
                      width: 9,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xB5F7FBFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    child: Container(
                      width: 10,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0x73FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 8,
                      height: 2.2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel() {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111111),
        border: Border.all(color: const Color(0xAAFFFFFF), width: 0.6),
      ),
    );
  }
}
