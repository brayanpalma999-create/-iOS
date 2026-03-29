class LocationModel {
  LocationModel({
    required this.latitude,
    required this.longitude,
    this.speed = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    "latitude": latitude,
    "longitude": longitude,
    "speed": speed,
    "timestamp": timestamp.toIso8601String(),
  };

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json["latitude"] as num).toDouble(),
      longitude: (json["longitude"] as num).toDouble(),
      speed: ((json["speed"] ?? 0) as num).toDouble(),
      timestamp:
          DateTime.tryParse(json["timestamp"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}
