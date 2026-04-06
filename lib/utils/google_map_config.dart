import "package:google_maps_flutter/google_maps_flutter.dart" as gmap;
import "package:latlong2/latlong.dart";

import "../providers/map_ui_provider.dart";
import "constants.dart";

class AppGoogleMapConfig {
  const AppGoogleMapConfig._();

  static String get apiKey => AppConstants.googleMapsApiKey;

  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static gmap.MapType mapTypeForMode(MapThemeMode mode) {
    return switch (mode) {
      MapThemeMode.flow => gmap.MapType.normal,
      MapThemeMode.dark => gmap.MapType.normal,
      MapThemeMode.satellite => gmap.MapType.hybrid,
    };
  }

  static String? styleForMode(MapThemeMode mode) {
    // Google Maps styling was causing intermittent blank/black renders on
    // Android while zooming. We keep the renderer stable first and can
    // reintroduce a production-tested dark style later.
    return null;
  }

  static gmap.LatLng latLng(LatLng value) {
    return gmap.LatLng(value.latitude, value.longitude);
  }

  static List<gmap.LatLng> latLngs(List<LatLng> values) {
    return values.map(latLng).toList(growable: false);
  }

  static LatLng latLngFromGoogle(gmap.LatLng value) {
    return LatLng(value.latitude, value.longitude);
  }

  static gmap.LatLngBounds boundsFromLatLng(List<LatLng> values) {
    assert(values.isNotEmpty);
    var minLat = values.first.latitude;
    var maxLat = values.first.latitude;
    var minLng = values.first.longitude;
    var maxLng = values.first.longitude;

    for (final value in values.skip(1)) {
      if (value.latitude < minLat) minLat = value.latitude;
      if (value.latitude > maxLat) maxLat = value.latitude;
      if (value.longitude < minLng) minLng = value.longitude;
      if (value.longitude > maxLng) maxLng = value.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0008) {
      minLat -= 0.0008;
      maxLat += 0.0008;
    }
    if ((maxLng - minLng).abs() < 0.0008) {
      minLng -= 0.0008;
      maxLng += 0.0008;
    }

    return gmap.LatLngBounds(
      southwest: gmap.LatLng(minLat, minLng),
      northeast: gmap.LatLng(maxLat, maxLng),
    );
  }
}
