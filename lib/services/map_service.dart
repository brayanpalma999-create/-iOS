import "dart:convert";
import "dart:io";

import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/driver_model.dart";
import "../utils/constants.dart";

class AddressSuggestion {
  const AddressSuggestion({
    required this.mainText,
    required this.secondaryText,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    this.isRecent = false,
  });

  final String mainText;
  final String secondaryText;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final bool isRecent;

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
  static const String _recentPlacesKey = "atob_recent_places_v1";
  static const Duration _networkTimeout = Duration(seconds: 8);

  LatLng centerFromDrivers(List<DriverModel> drivers, {LatLng? fallback}) {
    final validDrivers = drivers
        .where(
          (driver) =>
              driver.location.latitude.abs() > 0.001 ||
              driver.location.longitude.abs() > 0.001,
        )
        .toList();
    if (validDrivers.isEmpty) {
      return fallback ?? const LatLng(37.0902, -95.7129);
    }

    var lat = 0.0;
    var lng = 0.0;
    for (final driver in validDrivers) {
      lat += driver.location.latitude;
      lng += driver.location.longitude;
    }

    return LatLng(lat / validDrivers.length, lng / validDrivers.length);
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
    final recent = await _loadRecentSuggestions(
      value,
      limit: limit,
      proximity: proximity,
    );
    if (value.length < 3) {
      return recent;
    }
    if (!AppConstants.hasMapboxToken) {
      final fallback = await _autocompleteWithNominatim(
        value,
        limit: limit,
        proximity: proximity,
      );
      return _mergeSuggestions(recent, fallback, limit: limit);
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
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, "AtoB/1.0");
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return <AddressSuggestion>[];
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return <AddressSuggestion>[];
      }

      final features = json["features"];
      if (features is! List) {
        return <AddressSuggestion>[];
      }

      final suggestions = features
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
      return _mergeSuggestions(
        recent,
        _filterByProximity(suggestions, proximity),
        limit: limit,
      );
    } catch (_) {
      return recent;
    } finally {
      client.close(force: true);
    }
  }

  Future<List<AddressSuggestion>> _autocompleteWithNominatim(
    String query, {
    required int limit,
    LatLng? proximity,
  }) async {
    final encoded = Uri.encodeComponent(query);
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$encoded"
      "&format=jsonv2"
      "&addressdetails=1"
      "&limit=$limit"
      "&accept-language=es",
    );
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, "AtoB/1.0");
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return <AddressSuggestion>[];
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
      final json = jsonDecode(body);
      if (json is! List) {
        return <AddressSuggestion>[];
      }

      final suggestions = <AddressSuggestion>[];
      for (final item in json.whereType<Map>()) {
        final map = item.cast<String, dynamic>();
        final display = map["display_name"]?.toString().trim() ?? "";
        if (display.isEmpty) continue;
        final parts = display.split(",");
        final main = parts.first.trim();
        final secondary = parts
            .skip(1)
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .take(3)
            .join(", ");
        final lat = _toDouble(map["lat"]);
        final lon = _toDouble(map["lon"]);
        suggestions.add(
          AddressSuggestion(
            mainText: main.isEmpty ? display : main,
            secondaryText: secondary,
            fullAddress: display,
            latitude: lat,
            longitude: lon,
          ),
        );
      }

      return _mergeSuggestions(
        await _loadRecentSuggestions(query, limit: limit, proximity: proximity),
        _filterByProximity(suggestions, proximity),
        limit: limit,
      );
    } catch (_) {
      return _loadRecentSuggestions(query, limit: limit, proximity: proximity);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> rememberAddress(AddressSuggestion suggestion) async {
    if (suggestion.fullAddress.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentPlacesKey) ?? <String>[];
    final items = <Map<String, dynamic>>[];
    for (final encoded in raw) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map<String, dynamic>) {
          items.add(decoded);
        } else if (decoded is Map) {
          items.add(decoded.cast<String, dynamic>());
        }
      } catch (_) {
        // Ignore malformed entries.
      }
    }
    items.removeWhere(
      (item) =>
          (item["fullAddress"]?.toString().trim().toLowerCase() ?? "") ==
          suggestion.fullAddress.trim().toLowerCase(),
    );
    items.insert(0, {
      "mainText": suggestion.mainText,
      "secondaryText": suggestion.secondaryText,
      "fullAddress": suggestion.fullAddress,
      "latitude": suggestion.latitude,
      "longitude": suggestion.longitude,
      "savedAt": DateTime.now().toIso8601String(),
    });
    final trimmed = items.take(12).map(jsonEncode).toList();
    await prefs.setStringList(_recentPlacesKey, trimmed);
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
    if (!AppConstants.hasMapboxToken) {
      return _calculateRouteWithOsrm(origin: origin, destination: destination);
    }
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
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, "AtoB/1.0");
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
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

  Future<RouteEstimate?> calculateRouteChain({
    required List<LatLng> stops,
  }) async {
    final cleaned = <LatLng>[];
    for (final stop in stops) {
      if (cleaned.isEmpty) {
        cleaned.add(stop);
        continue;
      }
      final last = cleaned.last;
      if ((last.latitude - stop.latitude).abs() < 0.00001 &&
          (last.longitude - stop.longitude).abs() < 0.00001) {
        continue;
      }
      cleaned.add(stop);
    }
    if (cleaned.length < 2) return null;
    if (cleaned.length == 2) {
      return calculateRoute(origin: cleaned.first, destination: cleaned.last);
    }

    final coords = cleaned
        .map((point) => "${point.longitude},${point.latitude}")
        .join(";");
    if (!AppConstants.hasMapboxToken) {
      return _calculateRouteChainWithOsrm(stops: cleaned);
    }
    final url = Uri.parse(
      "https://api.mapbox.com/directions/v5/mapbox/driving/$coords"
      "?alternatives=false"
      "&continue_straight=true"
      "&geometries=geojson"
      "&overview=full"
      "&steps=false"
      "&access_token=${AppConstants.mapboxToken}",
    );
    final estimate = await _requestRouteEstimate(url, fallbackPath: cleaned);
    return estimate ?? _calculateRouteChainWithOsrm(stops: cleaned);
  }

  Future<RouteEstimate?> _calculateRouteWithOsrm({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coords =
        "${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}";
    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/$coords"
      "?overview=full"
      "&geometries=geojson"
      "&steps=false",
    );
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, "AtoB/1.0");
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return _fallbackEstimate(origin: origin, destination: destination);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
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

  Future<RouteEstimate?> _calculateRouteChainWithOsrm({
    required List<LatLng> stops,
  }) async {
    final coords = stops
        .map((point) => "${point.longitude},${point.latitude}")
        .join(";");
    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/$coords"
      "?overview=full"
      "&geometries=geojson"
      "&steps=false",
    );
    return _requestRouteEstimate(url, fallbackPath: stops);
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

  Future<RouteEstimate?> _requestRouteEstimate(
    Uri url, {
    required List<LatLng> fallbackPath,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, "AtoB/1.0");
      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode != 200) {
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      final routes = json["routes"];
      if (routes is! List || routes.isEmpty) {
        return null;
      }
      final first = routes.first;
      if (first is! Map) {
        return null;
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
        path.addAll(fallbackPath);
      }
      return RouteEstimate(
        distanceMiles: miles,
        durationMinutes: seconds / 60,
        fareUsd: fare,
        path: path,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  double fareForMiles(double miles) {
    if (miles < AppConstants.minimumFareMiles) {
      return AppConstants.minimumTripFare;
    }
    return miles * AppConstants.farePerMile;
  }

  double? _toDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  List<AddressSuggestion> _filterByProximity(
    List<AddressSuggestion> suggestions,
    LatLng? proximity,
  ) {
    if (suggestions.isEmpty || proximity == null) return suggestions;
    final distance = const Distance();
    suggestions.sort((a, b) {
      final ap = a.point;
      final bp = b.point;
      if (ap == null && bp == null) return 0;
      if (ap == null) return 1;
      if (bp == null) return -1;
      final ad = distance.as(LengthUnit.Meter, proximity, ap);
      final bd = distance.as(LengthUnit.Meter, proximity, bp);
      return ad.compareTo(bd);
    });

    final radiusMeters = AppConstants.suggestionRadiusKm * 1000;
    final near = suggestions.where((item) {
      final point = item.point;
      if (point == null) return false;
      final meters = distance.as(LengthUnit.Meter, proximity, point);
      return meters <= radiusMeters;
    }).toList();

    if (near.isNotEmpty) return near;
    return <AddressSuggestion>[];
  }

  Future<List<AddressSuggestion>> _loadRecentSuggestions(
    String query, {
    required int limit,
    LatLng? proximity,
  }) async {
    final normalized = query.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentPlacesKey) ?? <String>[];
    final matches = <AddressSuggestion>[];
    for (final encoded in raw) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! Map) continue;
        final map = decoded.cast<String, dynamic>();
        final fullAddress = map["fullAddress"]?.toString().trim() ?? "";
        final mainText = map["mainText"]?.toString().trim() ?? fullAddress;
        final secondaryText = map["secondaryText"]?.toString().trim() ?? "";
        if (fullAddress.isEmpty) continue;
        if (normalized.isNotEmpty &&
            !fullAddress.toLowerCase().contains(normalized) &&
            !mainText.toLowerCase().contains(normalized)) {
          continue;
        }
        matches.add(
          AddressSuggestion(
            mainText: mainText,
            secondaryText: secondaryText.isEmpty
                ? "Visitado antes"
                : "Visitado antes - $secondaryText",
            fullAddress: fullAddress,
            latitude: _toDouble(map["latitude"]),
            longitude: _toDouble(map["longitude"]),
            isRecent: true,
          ),
        );
      } catch (_) {
        // Ignore malformed entries.
      }
    }
    return _filterByProximity(matches, proximity).take(limit).toList();
  }

  List<AddressSuggestion> _mergeSuggestions(
    List<AddressSuggestion> primary,
    List<AddressSuggestion> secondary, {
    required int limit,
  }) {
    final merged = <AddressSuggestion>[];
    final seen = <String>{};
    for (final item in [...primary, ...secondary]) {
      final key = item.fullAddress.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      merged.add(item);
      if (merged.length >= limit) break;
    }
    return merged;
  }
}
