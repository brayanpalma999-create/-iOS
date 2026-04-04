import "../models/trip_model.dart";
import "../models/location_model.dart";

class TripService {
  static const double adminServiceFeeRate = 0.25;
  static const double driverNetRate = 0.75;

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
    List<RouteStepModel> routeSteps = const <RouteStepModel>[],
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
      routeSteps: routeSteps,
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

  void replaceAll(List<TripModel> trips) {
    _trips
      ..clear()
      ..addAll(trips);
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

  void updateTrip(
    String tripId, {
    String? status,
    double? distanceMiles,
    double? durationMinutes,
    double? fareUsd,
    List<LocationModel>? routePoints,
    List<RouteStepModel>? routeSteps,
    LocationModel? originLocation,
    LocationModel? destinationLocation,
  }) {
    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index < 0) return;
    _trips[index] = _trips[index].copyWith(
      status: status,
      distanceMiles: distanceMiles,
      durationMinutes: durationMinutes,
      fareUsd: fareUsd,
      routePoints: routePoints,
      routeSteps: routeSteps,
      originLocation: originLocation,
      destinationLocation: destinationLocation,
    );
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
      if (t.status == "assigned" ||
          t.status == "accepted" ||
          t.status == "picked_up") {
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
        .where(
          (t) =>
              t.status == "assigned" ||
              t.status == "accepted" ||
              t.status == "picked_up",
        )
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

  double serviceFeeForTrip(TripModel trip) => trip.fareUsd * adminServiceFeeRate;

  double driverNetForTrip(TripModel trip) => trip.fareUsd * driverNetRate;

  double serviceFeeRevenue({String? driverId, bool confirmedOnly = false}) {
    final source = _filteredTrips(driverId: driverId, confirmedOnly: confirmedOnly);
    return source.fold<double>(0, (sum, trip) => sum + serviceFeeForTrip(trip));
  }

  double driverNetRevenue({String? driverId, bool confirmedOnly = false}) {
    final source = _filteredTrips(driverId: driverId, confirmedOnly: confirmedOnly);
    return source.fold<double>(0, (sum, trip) => sum + driverNetForTrip(trip));
  }

  double averageDriverNet({String? driverId}) {
    final valid = _filteredTrips(driverId: driverId, confirmedOnly: false).toList();
    if (valid.isEmpty) return 0;
    final total = valid.fold<double>(0, (sum, trip) => sum + driverNetForTrip(trip));
    return total / valid.length;
  }

  bool countsTowardConfirmedEarnings(TripModel trip) =>
      _isCompletedStatus(trip.status);

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

  Iterable<TripModel> _filteredTrips({
    String? driverId,
    required bool confirmedOnly,
  }) {
    final source = driverId == null
        ? _trips
        : _trips.where((trip) => trip.driverId == driverId);
    if (confirmedOnly) {
      return source.where((trip) => _isCompletedStatus(trip.status));
    }
    return source.where((trip) => trip.status != "rejected");
  }

  bool _isCompletedStatus(String status) {
    return status == "completed" ||
        status == "accepted" ||
        status == "picked_up";
  }
}
