import "dart:convert";
import "dart:io";

import "package:latlong2/latlong.dart";

import "../models/driver_model.dart";
import "../utils/constants.dart";

class AddressSuggestion {
  const AddressSuggestion({
    required this.mainText,
    required this.secondaryText,
    required this.fullAddress,
    this.latitude,
    this.longitude,
  });

  final String mainText;
  final String secondaryText;
  final String fullAddress;
  final double? latitude;
  final double? longitude;

  LatLng? get point {
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude!, longitude!);
  }
}

class RouteEstimate {
  const RouteEstimate({
    required this.distanceMiles,
    required this.durationMinutes,
    required this.fareUsd,
    required this.path,
  });

  final double distanceMiles;
  final double durationMinutes;
  final double fareUsd;
  final List<LatLng> path;
}

class MapService {
  LatLng centerFromDrivers(List<DriverModel> drivers, {LatLng? fallback}) {
    if (drivers.isEmpty) {
      return fallback ?? const LatLng(19.4326, -99.1332);
    }

    var lat = 0.0;
    var lng = 0.0;
    for (final driver in drivers) {
      lat += driver.location.latitude;
      lng += driver.location.longitude;
    }

    return LatLng(lat / drivers.length, lng / drivers.length);
  }

  double dynamicZoom(int driverCount) {
    if (driverCount <= 1) return 15.5;
    if (driverCount <= 3) return 13.5;
    if (driverCount <= 10) return 12;
    return 11;
  }

  Future<List<AddressSuggestion>> autocompleteAddress(
    String query, {
    int limit = 5,
    LatLng? proximity,
  }) async {
    final value = query.trim();
    if (value.length < 3) {
      return <AddressSuggestion>[];
    }

    final encoded = Uri.encodeComponent(value);
    final proximityQuery = proximity == null
        ? ""
        : "&proximity=${proximity.longitude},${proximity.latitude}";
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json"
      "?autocomplete=true"
      "&types=address,place,locality,neighborhood,poi"
      "&language=es"
      "&limit=$limit"
      "$proximityQuery"
      "&access_token=${AppConstants.mapboxToken}",
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        return <AddressSuggestion>[];
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return <AddressSuggestion>[];
      }

      final features = json["features"];
      if (features is! List) {
        return <AddressSuggestion>[];
      }

      return features
          .whereType<Map>()
          .map((f) => f.cast<String, dynamic>())
          .map((feature) {
            final placeName = feature["place_name"]?.toString() ?? "";
            final text = feature["text"]?.toString() ?? placeName;
            final context = feature["context"];
            final center = feature["center"];
            String secondary = "";
            if (context is List) {
              final names = context
                  .whereType<Map>()
                  .map((c) => c["text"]?.toString() ?? "")
                  .where((s) => s.isNotEmpty)
                  .toList();
              secondary = names.take(3).join(", ");
            }
            double? longitude;
            double? latitude;
            if (center is List && center.length >= 2) {
              final lonRaw = center[0];
              final latRaw = center[1];
              if (lonRaw is num && latRaw is num) {
                longitude = lonRaw.toDouble();
                latitude = latRaw.toDouble();
              }
            }
            return AddressSuggestion(
              mainText: text,
              secondaryText: secondary,
              fullAddress: placeName.isEmpty ? text : placeName,
              latitude: latitude,
              longitude: longitude,
            );
          })
          .where((s) => s.fullAddress.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <AddressSuggestion>[];
    } finally {
      client.close(force: true);
    }
  }

  Future<LatLng?> geocodeAddress(String query, {LatLng? proximity}) async {
    final results = await autocompleteAddress(
      query,
      limit: 1,
      proximity: proximity,
    );
    if (results.isEmpty) return null;
    return results.first.point;
  }

  Future<RouteEstimate?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coords =
        "${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}";
    final url = Uri.parse(
      "https://api.mapbox.com/directions/v5/mapbox/driving/$coords"
      "?alternatives=false"
      "&continue_straight=true"
      "&geometries=geojson"
      "&overview=full"
      "&steps=false"
      "&access_token=${AppConstants.mapboxToken}",
    );

    final client = HttpClient();
    try {
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }
      final routes = json["routes"];
      if (routes is! List || routes.isEmpty) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }
      final first = routes.first;
      if (first is! Map) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }
      final map = first.cast<String, dynamic>();
      final meters = (map["distance"] as num?)?.toDouble() ?? 0;
      final seconds = (map["duration"] as num?)?.toDouble() ?? 0;
      final miles = meters / 1609.344;
      final fare = fareForMiles(miles);

      final path = <LatLng>[];
      final geometry = map["geometry"];
      if (geometry is Map) {
        final coordinates = geometry["coordinates"];
        if (coordinates is List) {
          for (final item in coordinates) {
            if (item is List && item.length >= 2) {
              final lon = item[0];
              final lat = item[1];
              if (lon is num && lat is num) {
                path.add(LatLng(lat.toDouble(), lon.toDouble()));
              }
            }
          }
        }
      }

      if (path.isEmpty) {
        path.addAll([origin, destination]);
      }

      return RouteEstimate(
        distanceMiles: miles,
        durationMinutes: seconds / 60,
        fareUsd: fare,
        path: path,
      );
    } catch (_) {
      return _fallbackEstimate(origin: origin, destination: destination);
    } finally {
      client.close(force: true);
    }
  }

  RouteEstimate _fallbackEstimate({
    required LatLng origin,
    required LatLng destination,
  }) {
    const distance = Distance();
    final miles = distance.as(LengthUnit.Mile, origin, destination);
    final fare = fareForMiles(miles);
    // Approx 25 mph urban average.
    final durationMinutes = (miles / 25) * 60;
    return RouteEstimate(
      distanceMiles: miles,
      durationMinutes: durationMinutes,
      fareUsd: fare,
      path: [origin, destination],
    );
  }

  double fareForMiles(double miles) {
    if (miles < AppConstants.minimumFareMiles) {
      return AppConstants.minimumTripFare;
    }
    return miles * AppConstants.farePerMile;
  }
}
