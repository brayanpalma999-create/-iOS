import "dart:typed_data";
import "dart:ui" as ui;

import "package:flutter/material.dart";

class MapboxMarkerFactory {
  const MapboxMarkerFactory._();

  static final Map<String, Future<Uint8List>> _cache =
      <String, Future<Uint8List>>{};

  static Future<Uint8List> carMarker({
    required bool active,
    bool compact = false,
  }) {
    final key = "car:${active ? "on" : "off"}:${compact ? "compact" : "full"}";
    return _cache.putIfAbsent(
      key,
      () => _drawCarMarker(active: active, compact: compact),
    );
  }

  static Future<Uint8List> stopMarker({
    required IconData icon,
    required Color color,
  }) {
    final key =
        "stop:${icon.codePoint}:${color.toARGB32().toRadixString(16)}";
    return _cache.putIfAbsent(
      key,
      () => _drawStopMarker(icon: icon, color: color),
    );
  }

  static Future<Uint8List> _drawCarMarker({
    required bool active,
    required bool compact,
  }) async {
    final accent = active ? const Color(0xFF4EA6FF) : const Color(0xFF8D949E);
    final deepAccent = active
        ? const Color(0xFF1D6FE2)
        : const Color(0xFF5A616D);
    final size = compact ? const ui.Size(72, 72) : const ui.Size(88, 88);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size.width / 2, size.height / 2);
    final carWidth = compact ? 24.0 : 28.0;
    final carHeight = compact ? 32.0 : 36.0;

    final shadowPaint = Paint()
      ..color = const Color(0x88000000)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 16),
        width: compact ? 24 : 30,
        height: compact ? 8 : 10,
      ),
      shadowPaint,
    );

    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(center.dx, center.dy + 4),
      compact ? 14 : 16,
      glowPaint,
    );

    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 6),
        width: carWidth,
        height: carHeight,
      ),
      const Radius.circular(12),
    );
    final carPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - 16),
        Offset(center.dx, center.dy + 24),
        <Color>[
          accent.withValues(alpha: 0.98),
          deepAccent.withValues(alpha: 0.92),
        ],
      );
    canvas.drawRRect(carRect, carPaint);
    canvas.drawRRect(
      carRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.34),
    );

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 1),
        width: compact ? 13 : 16,
        height: compact ? 9 : 11,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      windshieldRect,
      Paint()..color = const Color(0xBDEAF5FF),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 10),
          width: compact ? 15 : 18,
          height: compact ? 5 : 6,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );

    final headlightPaint = Paint()..color = const Color(0xFFF5FDFF);
    canvas.drawCircle(
      Offset(center.dx - (compact ? 4.8 : 5.8), center.dy - 11),
      compact ? 1.7 : 2,
      headlightPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + (compact ? 4.8 : 5.8), center.dy - 11),
      compact ? 1.7 : 2,
      headlightPaint,
    );

    final tailPaint = Paint()..color = const Color(0xFF0B1220);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 19),
          width: compact ? 10 : 12,
          height: 3,
        ),
        const Radius.circular(999),
      ),
      tailPaint,
    );

    for (final dx in <double>[-8.5, 8.5]) {
      canvas.drawCircle(
        Offset(center.dx + dx, center.dy + 19),
        compact ? 3.2 : 3.8,
        Paint()..color = const Color(0xFF101010),
      );
      canvas.drawCircle(
        Offset(center.dx + dx, center.dy + 19),
        compact ? 1.6 : 1.9,
        Paint()..color = Colors.white.withValues(alpha: 0.72),
      );
    }

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _drawStopMarker({
    required IconData icon,
    required Color color,
  }) async {
    const size = ui.Size(74, 74);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(37, 37);

    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
    );

    canvas.drawCircle(
      center,
      15,
      Paint()..color = const Color(0xF3131313),
    );
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = color,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 17,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    return _toPng(recorder, size);
  }

  static Future<Uint8List> _toPng(
    ui.PictureRecorder recorder,
    ui.Size size,
  ) async {
    final image = await recorder
        .endRecording()
        .toImage(size.width.ceil(), size.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError("No se pudo generar el marcador de Mapbox.");
    }
    return bytes.buffer.asUint8List();
  }
}
