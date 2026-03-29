import "dart:async";
import "dart:io";

import "package:socket_io_client/socket_io_client.dart" as io;

const _url = String.fromEnvironment(
  "PROBE_URL",
  defaultValue: "http://127.0.0.1:3000",
);
const _path = String.fromEnvironment("PROBE_PATH", defaultValue: "/socket.io");

Future<void> main() async {
  final admin = _connect();
  final driver = _connect();

  final gotDriverList = Completer<void>();
  final gotAssigned = Completer<void>();
  final gotAccepted = Completer<void>();

  String? driverId;
  String? tripId;
  var routePayloadOk = false;

  admin.on("drivers:list", (data) {
    if (data is! List) return;
    if (data.isEmpty) return;
    final first = data.first;
    if (first is! Map) return;
    final id = first["id"]?.toString();
    if (id == null || id.isEmpty) return;
    driverId = id;
    if (!gotDriverList.isCompleted) gotDriverList.complete();
  });

  driver.on("trip:assigned", (data) {
    stdout.writeln("driver trip:assigned -> $data");
    if (data is! Map) return;
    tripId = data["id"]?.toString();
    final route = data["routePoints"];
    final hasRoute = route is List && route.length >= 2;
    final duration = (data["durationMinutes"] as num?)?.toDouble() ?? 0;
    final miles = (data["distanceMiles"] as num?)?.toDouble() ?? 0;
    routePayloadOk = hasRoute && duration > 0 && miles > 0;
    if (!gotAssigned.isCompleted) gotAssigned.complete();
  });

  admin.on("trip:accepted", (data) {
    stdout.writeln("admin trip:accepted -> $data");
    if (!gotAccepted.isCompleted) gotAccepted.complete();
  });

  await _waitConnected(admin, "admin");
  await _waitConnected(driver, "driver");

  admin.emit("register", {"role": "admin", "name": "Probe Admin"});
  driver.emit("register", {"role": "driver", "name": "Probe Driver"});
  admin.emit("drivers:request", {});

  await gotDriverList.future.timeout(const Duration(seconds: 8));
  final selectedDriver = driverId;
  if (selectedDriver == null) {
    throw Exception("No se obtuvo driverId");
  }

  admin.emit("assign:trip", {
    "id": "probe-trip-1",
    "driverId": selectedDriver,
    "origin": "Origen Probe",
    "destination": "Destino Probe",
    "status": "assigned",
    "createdAt": DateTime.now().toIso8601String(),
    "distanceMiles": 4.2,
    "durationMinutes": 11,
    "fareUsd": 9.45,
    "routePoints": [
      {"latitude": 19.4302, "longitude": -99.1402},
      {"latitude": 19.4329, "longitude": -99.1331},
    ],
    "originLocation": {"latitude": 19.4302, "longitude": -99.1402},
    "destinationLocation": {"latitude": 19.4329, "longitude": -99.1331},
  });

  await gotAssigned.future.timeout(const Duration(seconds: 8));
  if (!routePayloadOk) {
    throw Exception(
      "El driver no recibio ruta/duracion/distancia en trip:assigned",
    );
  }

  final assignedTripId = tripId;
  if (assignedTripId == null) {
    throw Exception("No se obtuvo tripId asignado");
  }

  driver.emit("trip:accepted", {"tripId": assignedTripId});
  await gotAccepted.future.timeout(const Duration(seconds: 8));

  stdout.writeln("Probe OK: asignacion y aceptacion sincronizadas.");
  admin.dispose();
  driver.dispose();
}

io.Socket _connect() {
  final socket = io.io(
    _url,
    io.OptionBuilder()
        .enableForceNew()
        .setTransports(["websocket", "polling"])
        .setPath(_path)
        .setTimeout(10000)
        .enableReconnection()
        .disableAutoConnect()
        .build(),
  );
  socket.connect();
  return socket;
}

Future<void> _waitConnected(io.Socket socket, String label) async {
  if (socket.connected) return;
  final completer = Completer<void>();
  late void Function(dynamic) onConnect;
  late void Function(dynamic) onError;
  onConnect = (_) {
    socket.off("connect", onConnect);
    socket.off("connect_error", onError);
    if (!completer.isCompleted) completer.complete();
  };
  onError = (e) {
    if (!completer.isCompleted) {
      completer.completeError("[$label] connect_error: $e");
    }
  };
  socket.on("connect", onConnect);
  socket.on("connect_error", onError);
  await completer.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw "[$label] timeout de conexion",
  );
}
