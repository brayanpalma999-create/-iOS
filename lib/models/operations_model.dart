class OperationsCountModel {
  const OperationsCountModel({
    required this.onlineDrivers,
    required this.connectedDrivers,
    required this.activeValidDrivers,
    required this.pendingActivations,
    required this.totalAccounts,
    required this.totalTrips,
    required this.activeTrips,
    required this.completedTrips,
    required this.auditEvents,
    required this.notifications,
  });

  final int onlineDrivers;
  final int connectedDrivers;
  final int activeValidDrivers;
  final int pendingActivations;
  final int totalAccounts;
  final int totalTrips;
  final int activeTrips;
  final int completedTrips;
  final int auditEvents;
  final int notifications;

  factory OperationsCountModel.fromJson(Map<String, dynamic> json) {
    int value(String key) => (json[key] as num?)?.toInt() ?? 0;
    return OperationsCountModel(
      onlineDrivers: value("onlineDrivers"),
      connectedDrivers: value("connectedDrivers"),
      activeValidDrivers: value("activeValidDrivers"),
      pendingActivations: value("pendingActivations"),
      totalAccounts: value("totalAccounts"),
      totalTrips: value("totalTrips"),
      activeTrips: value("activeTrips"),
      completedTrips: value("completedTrips"),
      auditEvents: value("auditEvents"),
      notifications: value("notifications"),
    );
  }
}

class OperationsSystemModel {
  const OperationsSystemModel({
    required this.persistenceMode,
    required this.renderRuntime,
    required this.persistentDisk,
    required this.inviteEmailConfigured,
    required this.liveKitConfigured,
    this.warning,
  });

  final String persistenceMode;
  final bool renderRuntime;
  final bool persistentDisk;
  final bool inviteEmailConfigured;
  final bool liveKitConfigured;
  final String? warning;

  bool get isStorageHealthy => !renderRuntime || persistentDisk;

  factory OperationsSystemModel.fromJson(Map<String, dynamic> json) {
    return OperationsSystemModel(
      persistenceMode: json["persistenceMode"]?.toString() ?? "filesystem",
      renderRuntime: json["renderRuntime"] as bool? ?? false,
      persistentDisk: json["persistentDisk"] as bool? ?? false,
      inviteEmailConfigured: json["inviteEmailConfigured"] as bool? ?? false,
      liveKitConfigured: json["liveKitConfigured"] as bool? ?? false,
      warning: json["warning"]?.toString(),
    );
  }
}

class OperationsEventModel {
  const OperationsEventModel({
    required this.id,
    required this.type,
    required this.scope,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String scope;
  final String title;
  final String message;
  final String severity;
  final DateTime createdAt;

  factory OperationsEventModel.fromJson(Map<String, dynamic> json) {
    return OperationsEventModel(
      id: json["id"]?.toString() ?? "",
      type: json["type"]?.toString() ?? "system",
      scope: json["scope"]?.toString() ?? "operations",
      title: json["title"]?.toString() ?? "",
      message: json["message"]?.toString() ?? "",
      severity: json["severity"]?.toString() ?? "info",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}

class OperationsNotificationModel {
  const OperationsNotificationModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String message;
  final String status;
  final DateTime createdAt;

  factory OperationsNotificationModel.fromJson(Map<String, dynamic> json) {
    return OperationsNotificationModel(
      id: json["id"]?.toString() ?? "",
      kind: json["kind"]?.toString() ?? "general",
      title: json["title"]?.toString() ?? "",
      message: json["message"]?.toString() ?? "",
      status: json["status"]?.toString() ?? "new",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}

class DriverPerformanceModel {
  const DriverPerformanceModel({
    required this.driverId,
    required this.displayName,
    required this.email,
    required this.totalTrips,
    required this.completedTrips,
    required this.activeTrips,
    required this.grossRevenue,
    required this.serviceFee,
    required this.driverNet,
  });

  final String driverId;
  final String displayName;
  final String email;
  final int totalTrips;
  final int completedTrips;
  final int activeTrips;
  final double grossRevenue;
  final double serviceFee;
  final double driverNet;

  factory DriverPerformanceModel.fromJson(Map<String, dynamic> json) {
    double value(String key) => (json[key] as num?)?.toDouble() ?? 0;
    int count(String key) => (json[key] as num?)?.toInt() ?? 0;
    return DriverPerformanceModel(
      driverId: json["driverId"]?.toString() ?? "",
      displayName: json["displayName"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",
      totalTrips: count("totalTrips"),
      completedTrips: count("completedTrips"),
      activeTrips: count("activeTrips"),
      grossRevenue: value("grossRevenue"),
      serviceFee: value("serviceFee"),
      driverNet: value("driverNet"),
    );
  }
}

class OperationsSummaryModel {
  const OperationsSummaryModel({
    required this.generatedAt,
    required this.counts,
    required this.system,
    required this.recentAudit,
    required this.recentNotifications,
    required this.driverPerformance,
  });

  final DateTime generatedAt;
  final OperationsCountModel counts;
  final OperationsSystemModel system;
  final List<OperationsEventModel> recentAudit;
  final List<OperationsNotificationModel> recentNotifications;
  final List<DriverPerformanceModel> driverPerformance;

  factory OperationsSummaryModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) convert,
    ) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => convert(item.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return OperationsSummaryModel(
      generatedAt:
          DateTime.tryParse(json["generatedAt"]?.toString() ?? "") ??
          DateTime.now(),
      counts: OperationsCountModel.fromJson(
        (json["counts"] as Map? ?? const <String, dynamic>{})
            .cast<String, dynamic>(),
      ),
      system: OperationsSystemModel.fromJson(
        (json["system"] as Map? ?? const <String, dynamic>{})
            .cast<String, dynamic>(),
      ),
      recentAudit: parseList("recentAudit", OperationsEventModel.fromJson),
      recentNotifications: parseList(
        "recentNotifications",
        OperationsNotificationModel.fromJson,
      ),
      driverPerformance: parseList(
        "driverPerformance",
        DriverPerformanceModel.fromJson,
      ),
    );
  }
}
