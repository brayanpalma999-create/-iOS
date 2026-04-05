import "dart:convert";
import "dart:io";

import "package:latlong2/latlong.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/driver_model.dart";
import "../models/location_model.dart";
import "../models/trip_model.dart";
import "../utils/constants.dart";

class AddressSuggestion {
  const AddressSuggestion({
    required this.mainText,
    required this.secondaryText,
    required this.fullAddress,
    this.latitude,
    this.longitude,
    this.routableLatitude,
    this.routableLongitude,
    this.isRecent = false,
  });

  final String mainText;
  final String secondaryText;
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final double? routableLatitude;
  final double? routableLongitude;
  final bool isRecent;

  LatLng? get point {
    if (routableLatitude != null && routableLongitude != null) {
      return LatLng(routableLatitude!, routableLongitude!);
    }
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
    this.steps = const <RouteStepModel>[],
  });

  final double distanceMiles;
  final double durationMinutes;
  final double fareUsd;
  final List<LatLng> path;
  final List<RouteStepModel> steps;
}

class MapService {
  static const String _recentPlacesKey = "atob_recent_places_v1";
  static const Duration _networkTimeout = Duration(seconds: 12);

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
    final effectiveLimit = limit < 10 ? 10 : limit;
    final recent = await _loadRecentSuggestions(
      value,
      limit: effectiveLimit,
      proximity: proximity,
    );
    if (value.length < 2) {
      return recent.take(limit).toList();
    }
    if (!AppConstants.hasMapboxToken) {
      final fallback = await _autocompleteWithNominatim(
        value,
        limit: effectiveLimit,
        proximity: proximity,
      );
      return _mergeSuggestions(recent, fallback, limit: effectiveLimit)
          .take(limit)
          .toList();
    }

    final encoded = Uri.encodeComponent(value);
    final proximityQuery = proximity == null
        ? ""
        : "&proximity=${proximity.longitude},${proximity.latitude}";
    final url = Uri.parse(
      "https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json"
      "?autocomplete=true"
      "&fuzzyMatch=true"
      "&routing=true"
      "&types=poi,address,place,locality,neighborhood,postcode,district"
      "&language=es,en"
      "&limit=$effectiveLimit"
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
        final fallback = await _autocompleteWithNominatim(
          value,
          limit: effectiveLimit,
          proximity: proximity,
        );
        return _mergeSuggestions(recent, fallback, limit: effectiveLimit)
            .take(limit)
            .toList();
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_networkTimeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) {
        final fallback = await _autocompleteWithNominatim(
          value,
          limit: effectiveLimit,
          proximity: proximity,
        );
        return _mergeSuggestions(recent, fallback, limit: effectiveLimit)
            .take(limit)
            .toList();
      }

      final features = json["features"];
      if (features is! List) {
        final fallback = await _autocompleteWithNominatim(
          value,
          limit: effectiveLimit,
          proximity: proximity,
        );
        return _mergeSuggestions(recent, fallback, limit: effectiveLimit)
            .take(limit)
            .toList();
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
            final routablePoint = _extractRoutablePoint(feature);
            return AddressSuggestion(
              mainText: text,
              secondaryText: secondary,
              fullAddress: placeName.isEmpty ? text : placeName,
              latitude: latitude,
              longitude: longitude,
              routableLatitude: routablePoint?.latitude,
              routableLongitude: routablePoint?.longitude,
            );
          })
          .where((s) => s.fullAddress.trim().isNotEmpty)
          .toList();
      final filtered = _filterByProximity(suggestions, proximity);
      final fallback = filtered.length >= effectiveLimit
          ? const <AddressSuggestion>[]
          : await _autocompleteWithNominatim(
              value,
              limit: effectiveLimit,
              proximity: proximity,
            );
      return _mergeSuggestions(
        recent,
        _mergeSuggestions(filtered, fallback, limit: effectiveLimit),
        limit: effectiveLimit,
      ).take(limit).toList();
    } catch (_) {
      final fallback = await _autocompleteWithNominatim(
        value,
        limit: effectiveLimit,
        proximity: proximity,
      );
      return _mergeSuggestions(recent, fallback, limit: effectiveLimit)
          .take(limit)
          .toList();
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
            routableLatitude: lat,
            routableLongitude: lon,
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
      "routableLatitude": suggestion.routableLatitude,
      "routableLongitude": suggestion.routableLongitude,
      "savedAt": DateTime.now().toIso8601String(),
    });
    final trimmed = items.take(12).map(jsonEncode).toList();
    await prefs.setStringList(_recentPlacesKey, trimmed);
  }

  Future<LatLng?> geocodeAddress(String query, {LatLng? proximity}) async {
    final results = await geocodeCandidates(
      query,
      limit: 4,
      proximity: proximity,
    );
    if (results.isEmpty) return null;
    return results.first.point;
  }

  Future<List<AddressSuggestion>> geocodeCandidates(
    String query, {
    int limit = 6,
    LatLng? proximity,
  }) async {
    final primary = await autocompleteAddress(
      query,
      limit: limit,
      proximity: proximity,
    );
    if (proximity == null) return primary;
    final broad = await autocompleteAddress(query, limit: limit, proximity: null);
    return _mergeSuggestions(primary, broad, limit: limit);
  }

  Future<RouteEstimate?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!AppConstants.hasMapboxToken) {
      return _calculateRouteWithOsrm(origin: origin, destination: destination);
    }
    final traffic = await _calculateRouteWithMapboxProfile(
      profile: "driving-traffic",
      origin: origin,
      destination: destination,
    );
    if (traffic != null) return traffic;
    final driving = await _calculateRouteWithMapboxProfile(
      profile: "driving",
      origin: origin,
      destination: destination,
    );
    if (driving != null) return driving;
    return _calculateRouteWithOsrm(origin: origin, destination: destination);
  }

  Future<RouteEstimate?> _calculateRouteWithMapboxProfile({
    required String profile,
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coords =
        "${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}";
    final url = Uri.parse(
      "https://api.mapbox.com/directions/v5/mapbox/$profile/$coords"
      "?alternatives=false"
      "&continue_straight=true"
      "&geometries=geojson"
      "&overview=full"
      "&steps=true"
      "&access_token=${AppConstants.mapboxToken}",
    );

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

      if (path.length < 2) return null;
      final compactPath = _compactPolyline(path);
      if (!_isUsableRoutePath(compactPath, origin: origin, destination: destination)) {
        return null;
      }
      final steps = _extractRouteSteps(map);

      return RouteEstimate(
        distanceMiles: miles,
        durationMinutes: seconds / 60,
        fareUsd: fare,
        path: compactPath,
        steps: steps,
      );
    } catch (_) {
      return null;
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

    final mergedPath = <LatLng>[];
    final mergedSteps = <RouteStepModel>[];
    var totalMiles = 0.0;
    var totalMinutes = 0.0;
    var totalFare = 0.0;

    for (var i = 0; i < cleaned.length - 1; i++) {
      final leg = await calculateRoute(
        origin: cleaned[i],
        destination: cleaned[i + 1],
      );
      if (leg == null) return null;
      totalMiles += leg.distanceMiles;
      totalMinutes += leg.durationMinutes;
      totalFare += leg.fareUsd;
      mergedSteps.addAll(leg.steps);
      if (mergedPath.isEmpty) {
        mergedPath.addAll(leg.path);
      } else {
        mergedPath.addAll(leg.path.skip(1));
      }
    }

    return RouteEstimate(
      distanceMiles: totalMiles,
      durationMinutes: totalMinutes,
      fareUsd: totalFare,
      path: _compactPolyline(mergedPath),
      steps: mergedSteps,
    );
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
      "&steps=true",
    );
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
      if (path.length < 2) {
        return null;
      }
      final compactPath = _compactPolyline(path);
      if (!_isUsableRoutePath(compactPath, origin: origin, destination: destination)) {
        return null;
      }
      final steps = _extractRouteSteps(map);
      return RouteEstimate(
        distanceMiles: miles,
        durationMinutes: seconds / 60,
        fareUsd: fare,
        path: compactPath,
        steps: steps,
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

    if (near.isEmpty) return suggestions.take(10).toList();
    return _mergeSuggestions(near, suggestions, limit: 10);
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
            routableLatitude: _toDouble(map["routableLatitude"]),
            routableLongitude: _toDouble(map["routableLongitude"]),
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

  List<LatLng> _compactPolyline(List<LatLng> points) {
    if (points.length < 2) return points;
    final result = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      final previous = result.last;
      final current = points[i];
      if ((previous.latitude - current.latitude).abs() < 0.000001 &&
          (previous.longitude - current.longitude).abs() < 0.000001) {
        continue;
      }
      result.add(current);
    }
    return result;
  }

  bool _isUsableRoutePath(
    List<LatLng> path, {
    required LatLng origin,
    required LatLng destination,
  }) {
    if (path.length < 2) return false;
    final distance = const Distance();
    final originOffset = distance.as(LengthUnit.Meter, path.first, origin);
    final destinationOffset = distance.as(
      LengthUnit.Meter,
      path.last,
      destination,
    );
    if (originOffset > 280 || destinationOffset > 280) {
      return false;
    }

    final straightMeters = distance.as(LengthUnit.Meter, origin, destination);
    final traveledMeters = _polylineMeters(path);
    if (traveledMeters <= 0) return false;
    if (traveledMeters + 25 < straightMeters) return false;
    return true;
  }

  LatLng? _extractRoutablePoint(Map<String, dynamic> feature) {
    final candidates = <dynamic>[
      feature["routable_points"],
      feature["properties"],
      feature["coordinates"],
    ];
    for (final candidate in candidates) {
      final point = _routablePointFrom(candidate);
      if (point != null) return point;
    }
    return null;
  }

  LatLng? _routablePointFrom(dynamic value) {
    if (value is! Map) return null;
    final map = value.cast<String, dynamic>();
    final directList = map["routable_points"];
    if (directList is List) {
      for (final item in directList) {
        final point = _latLngFromDynamic(item);
        if (point != null) return point;
      }
    }
    final coordinates = map["coordinates"];
    if (coordinates is Map) {
      final nested = _routablePointFrom(coordinates);
      if (nested != null) return nested;
    }
    return _latLngFromDynamic(map);
  }

  LatLng? _latLngFromDynamic(dynamic raw) {
    if (raw is List && raw.length >= 2) {
      final lon = raw[0];
      final lat = raw[1];
      if (lon is num && lat is num) {
        return LatLng(lat.toDouble(), lon.toDouble());
      }
    }
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final latitude =
        _toDouble(map["latitude"]) ??
        _toDouble(map["lat"]) ??
        _toDouble(map["y"]);
    final longitude =
        _toDouble(map["longitude"]) ??
        _toDouble(map["lon"]) ??
        _toDouble(map["lng"]) ??
        _toDouble(map["x"]);
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  double _polylineMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    final distance = const Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return meters;
  }

  List<RouteStepModel> _extractRouteSteps(Map<String, dynamic> route) {
    final legs = route["legs"];
    if (legs is! List) return const <RouteStepModel>[];
    final steps = <RouteStepModel>[];
    for (final leg in legs.whereType<Map>()) {
      final map = leg.cast<String, dynamic>();
      final legSteps = map["steps"];
      if (legSteps is! List) continue;
      for (final raw in legSteps.whereType<Map>()) {
        final step = raw.cast<String, dynamic>();
        final maneuver = step["maneuver"];
        final distanceMeters = (step["distance"] as num?)?.toDouble() ?? 0;
        final durationSeconds = (step["duration"] as num?)?.toDouble() ?? 0;
        final roadName = step["name"]?.toString().trim();
        final instruction =
            maneuver is Map && maneuver["instruction"] != null
            ? maneuver["instruction"].toString().trim()
            : _fallbackInstruction(roadName, step["mode"]?.toString());
        double? latitude;
        double? longitude;
        if (maneuver is Map) {
          final location = maneuver["location"];
          if (location is List && location.length >= 2) {
            final lonRaw = location[0];
            final latRaw = location[1];
            if (lonRaw is num && latRaw is num) {
              longitude = lonRaw.toDouble();
              latitude = latRaw.toDouble();
            }
          }
        }
        if (instruction.isEmpty && distanceMeters <= 0) {
          continue;
        }
        steps.add(
          RouteStepModel(
            instruction: instruction.isEmpty
                ? "Continue"
                : instruction,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            roadName: roadName == null || roadName.isEmpty ? null : roadName,
            maneuverType: maneuver is Map ? maneuver["type"]?.toString() : null,
            maneuverModifier: maneuver is Map
                ? maneuver["modifier"]?.toString()
                : null,
            location: latitude == null || longitude == null
                ? null
                : LocationModel(latitude: latitude, longitude: longitude),
          ),
        );
      }
    }
    return steps;
  }

  String _fallbackInstruction(String? roadName, String? mode) {
    final road = (roadName ?? "").trim();
    if (road.isNotEmpty) return "Continue on $road";
    final normalizedMode = (mode ?? "").trim();
    if (normalizedMode.isNotEmpty) {
      return "Continue by $normalizedMode";
    }
    return "Continue";
  }
}
