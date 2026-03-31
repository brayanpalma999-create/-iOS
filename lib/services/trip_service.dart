import "../models/trip_model.dart";
import "../models/location_model.dart";

class TripService {
  final List<TripModel> _trips = <TripModel>[];

  List<TripModel> get trips => List.unmodifiable(_trips);

  TripModel createTrip({
    required String driverId,
    required String origin,
    required String destination,
    double distanceMiles = 0,
    double durationMinutes = 0,
    double fareUsd = 0,
    List<LocationModel> routePoints = const <LocationModel>[],
    LocationModel? originLocation,
    LocationModel? destinationLocation,
  }) {
    final trip = TripModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      driverId: driverId,
      origin: origin,
      destination: destination,
      status: "assigned",
      createdAt: DateTime.now(),
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      fareUsd: fareUsd,
      routePoints: routePoints,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    );
    return trip;
  }

  TripModel upsertTrip(TripModel trip) {
    final index = _trips.indexWhere((t) => t.id == trip.id);
    if (index >= 0) {
      _trips[index] = trip;
      return _trips[index];
    }
    _trips.insert(0, trip);
    return trip;
  }

  TripModel? byId(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  void updateStatus(String tripId, String status) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index < 0) {
      return;
    }
    _trips[index] = _trips[index].copyWith(status: status);
  }

  TripModel? latestForDriver(String driverId) {
    for (final t in _trips) {
      if (t.driverId == driverId) return t;
    }
    return null;
  }

  TripModel? latestActiveForDriver(String driverId) {
    for (final t in _trips) {
      if (t.driverId != driverId) continue;
      if (t.status == "assigned" || t.status == "accepted") {
        return t;
      }
    }
    return null;
  }

  int totalTrips({String? driverId}) {
    if (driverId == null) return _trips.length;
    return _trips.where((t) => t.driverId == driverId).length;
  }

  int totalActiveTrips({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    return source
        .where((t) => t.status == "assigned" || t.status == "accepted")
        .length;
  }

  double estimatedRevenue({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    return source
        .where((t) => t.status != "rejected")
        .fold<double>(0, (sum, t) => sum + t.fareUsd);
  }

  double confirmedRevenue({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    return source
        .where((t) => _isCompletedStatus(t.status))
        .fold<double>(0, (sum, t) => sum + t.fareUsd);
  }

  int completedTrips({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    return source.where((t) => _isCompletedStatus(t.status)).length;
  }

  int rejectedTrips({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    return source.where((t) => t.status == "rejected").length;
  }

  double acceptanceRate({String? driverId}) {
    final done = completedTrips(driverId: driverId);
    final rejected = rejectedTrips(driverId: driverId);
    final denominator = done + rejected;
    if (denominator == 0) return 0;
    return done / denominator;
  }

  double averageFare({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    final valid = source.where((t) => t.status != "rejected").toList();
    if (valid.isEmpty) return 0;
    final total = valid.fold<double>(0, (sum, t) => sum + t.fareUsd);
    return total / valid.length;
  }

  double averageDistanceMiles({String? driverId}) {
    final source = driverId == null
        ? _trips
        : _trips.where((t) => t.driverId == driverId);
    final valid = source.where((t) => t.distanceMiles > 0).toList();
    if (valid.isEmpty) return 0;
    final total = valid.fold<double>(0, (sum, t) => sum + t.distanceMiles);
    return total / valid.length;
  }

  void clear() {
    _trips.clear();
  }

  bool _isCompletedStatus(String status) {
    return status == "completed" || status == "accepted";
  }
}
