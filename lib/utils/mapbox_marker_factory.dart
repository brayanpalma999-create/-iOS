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
      () => _drawNavArrow(active: active, compact: compact),
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

  /// Navigation arrow pointing UP (north = 0°).
  /// Google Maps rotates it clockwise by the heading value.
  static Future<Uint8List> _drawNavArrow({
    required bool active,
    required bool compact,
  }) async {
    final accent = active ? const Color(0xFF4EA6FF) : const Color(0xFF8D949E);
    final deep = active ? const Color(0xFF1A5FD0) : const Color(0xFF5A616D);
    final size = compact ? const ui.Size(72, 72) : const ui.Size(88, 88);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // --- outer accuracy ring ---
    canvas.drawCircle(
      Offset(cx, cy),
      compact ? 28 : 34,
      Paint()
        ..color = accent.withValues(alpha: 0.12)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
    );

    // --- drop shadow ---
    final shadowArrow = _arrowPath(cx, cy, compact).shift(const Offset(0, 2));
    canvas.drawPath(
      shadowArrow,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
    );

    // --- main arrow ---
    final arrow = _arrowPath(cx, cy, compact);
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - (compact ? 18 : 22)),
          Offset(cx, cy + (compact ? 14 : 18)),
          <Color>[accent, deep],
        ),
    );

    // --- white edge highlight ---
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.50),
    );

    // --- center dot ---
    canvas.drawCircle(
      Offset(cx, cy + (compact ? 2 : 3)),
      compact ? 3.2 : 4.0,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );

    return _toPng(recorder, size);
  }

  /// Builds a chevron arrow pointing UP, centered at (cx, cy).
  static Path _arrowPath(double cx, double cy, bool compact) {
    final h = compact ? 30.0 : 38.0; // total height
    final w = compact ? 24.0 : 30.0; // total width
    final notch = h * 0.30; // depth of the rear notch

    final top = cy - h / 2;
    final bottom = cy + h / 2;

    return Path()
      ..moveTo(cx, top) // tip
      ..lineTo(cx + w / 2, bottom) // bottom-right
      ..lineTo(cx, bottom - notch) // inner notch
      ..lineTo(cx - w / 2, bottom) // bottom-left
      ..close();
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
