import "package:flutter/material.dart";

import "../models/driver_model.dart";
import "../models/location_model.dart";
import "../services/socket_service.dart";
import "driver_provider.dart";

class AdminProvider extends ChangeNotifier {
  AdminProvider({
    required SocketService socketService,
    required DriverProvider driverProvider,
  }) : _socketService = socketService,
       _driverProvider = driverProvider;

  final SocketService _socketService;
  final DriverProvider _driverProvider;

  bool _connected = false;

  bool get connected => _connected;
  List<DriverModel> get drivers => _driverProvider.drivers;

  void connectAdmin({required String id, required String name}) {
    _socketService.connect("admin:connect", {"id": id, "name": name});
    _driverProvider.attachAdminSession(name: name);
    _connected = true;
    _socketService.emit("drivers:request", {});
    notifyListeners();
  }

  void refreshDrivers() {
    _socketService.emit("drivers:request", {});
    notifyListeners();
  }

  void ingestDriverLocation({
    required String driverId,
    required LocationModel location,
  }) {
    _socketService.emit("driver:location", {
      "driverId": driverId,
      ...location.toJson(),
    });
  }

  void disconnect() {
    _socketService.disconnect();
    _connected = false;
    notifyListeners();
  }
}
