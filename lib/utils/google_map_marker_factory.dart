import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart" as gmap;

import "mapbox_marker_factory.dart";

class GoogleMapMarkerFactory {
  const GoogleMapMarkerFactory._();

  static final Map<String, Future<gmap.BitmapDescriptor>> _cache =
      <String, Future<gmap.BitmapDescriptor>>{};

  static Future<gmap.BitmapDescriptor> carMarker({
    required bool active,
    bool compact = false,
  }) {
    final key = "car:${active ? "on" : "off"}:${compact ? "compact" : "full"}";
    return _cache.putIfAbsent(key, () async {
      final bytes = await MapboxMarkerFactory.carMarker(
        active: active,
        compact: compact,
      );
      return gmap.BitmapDescriptor.bytes(bytes);
    });
  }

  static Future<gmap.BitmapDescriptor> stopMarker({
    required IconData icon,
    required int colorValue,
  }) {
    final key = "stop:${icon.codePoint}:$colorValue";
    return _cache.putIfAbsent(key, () async {
      final bytes = await MapboxMarkerFactory.stopMarker(
        icon: icon,
        color: Color(colorValue),
      );
      return gmap.BitmapDescriptor.bytes(bytes);
    });
  }
}
