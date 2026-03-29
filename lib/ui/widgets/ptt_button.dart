import "package:flutter/material.dart";
import "package:flutter/gestures.dart";

import "../../utils/constants.dart";

class PttButton extends StatefulWidget {
  const PttButton({
    super.key,
    required this.onPress,
    required this.onRelease,
    required this.active,
    required this.busy,
  });

  final Future<void> Function() onPress;
  final Future<void> Function() onRelease;
  final bool active;
  final bool busy;

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _holding = false;
  int? _trackingPointer;

  void _startHold() {
    if (_holding) return;
    _holding = true;
    widget.onPress();
  }

  void _endHold() {
    if (!_holding) return;
    _holding = false;
    widget.onRelease();
  }

  void _onGlobalPointerEvent(PointerEvent event) {
    final pointer = _trackingPointer;
    if (pointer == null || event.pointer != pointer) return;
    if (event is PointerUpEvent ||
        event is PointerRemovedEvent ||
        event is PointerCancelEvent) {
      _trackingPointer = null;
      _endHold();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0.95,
      upperBound: 1.12,
    );
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointerEvent);
  }

  @override
  void didUpdateWidget(covariant PttButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _trackingPointer = null;
      _holding = false;
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _onGlobalPointerEvent,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.busy ? Colors.orange : AppConstants.accent;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (_trackingPointer != null || _holding) return;
        _trackingPointer = event.pointer;
        _startHold();
      },
      onPointerUp: (event) {
        if (_trackingPointer != event.pointer) return;
        _trackingPointer = null;
        _endHold();
      },
      onPointerCancel: (event) {
        if (_trackingPointer != event.pointer) return;
        _trackingPointer = null;
        _endHold();
      },
      child: ScaleTransition(
        scale: _controller,
        child: Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.active
                    ? const [Color(0xFF0E2C33), Color(0xFF021014)]
                    : const [Color(0xFF171717), Color(0xFF0B0B0B)],
              ),
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: widget.active ? 0.6 : 0.25),
                  blurRadius: widget.active ? 30 : 12,
                  spreadRadius: widget.active ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              widget.active ? Icons.graphic_eq : Icons.mic,
              color: color,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}
