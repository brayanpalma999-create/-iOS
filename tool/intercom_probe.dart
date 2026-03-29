import "dart:async";
import "dart:io";

import "package:socket_io_client/socket_io_client.dart" as io;

const _url = "https://atob-server.onrender.com";
const _path = "/socket.io";

Future<void> main() async {
  final admin = _connect();
  final driver = _connect();

  final gotFirstStart = Completer<void>();
  final gotStop = Completer<void>();
  final gotSecondStart = Completer<void>();
  final gotPrivateStart = Completer<void>();

  var startCount = 0;

  driver.on("voice:start", (data) {
    startCount += 1;
    stdout.writeln("driver voice:start #$startCount -> $data");
    if (startCount == 1 && !gotFirstStart.isCompleted) {
      gotFirstStart.complete();
    }
    if (startCount == 2 && !gotSecondStart.isCompleted) {
      gotSecondStart.complete();
    }
    if (startCount == 3 && !gotPrivateStart.isCompleted) {
      gotPrivateStart.complete();
    }
  });
  driver.on("voice:stop", (data) {
    stdout.writeln("driver voice:stop -> $data");
    if (!gotStop.isCompleted) gotStop.complete();
  });
  driver.on("connect_error", (e) => stdout.writeln("driver connect_error: $e"));
  admin.on("connect_error", (e) => stdout.writeln("admin connect_error: $e"));

  await _waitConnected(admin, "admin");
  await _waitConnected(driver, "driver");

  final driverSocketId = driver.id;
  stdout.writeln("admin socket: ${admin.id}");
  stdout.writeln("driver socket: $driverSocketId");

  admin.emit("register", {"role": "admin", "name": "Probe Admin"});
  driver.emit("register", {"role": "driver", "name": "Probe Driver"});

  await Future<void>.delayed(const Duration(milliseconds: 500));

  admin.emit("voice:stop");
  await Future<void>.delayed(const Duration(milliseconds: 120));

  admin.emit("voice:start", {
    "channel": "global",
    "fromId": admin.id,
    "fromName": "Probe Admin",
  });

  await gotFirstStart.future.timeout(const Duration(seconds: 20));

  admin.emit("voice:chunk", {
    "payload": List<int>.filled(120, 128),
    "channel": "global",
    "fromId": admin.id,
    "fromName": "Probe Admin",
  });

  await Future<void>.delayed(const Duration(milliseconds: 300));
  admin.emit("voice:stop");

  await gotStop.future.timeout(const Duration(seconds: 20));

  await Future<void>.delayed(const Duration(milliseconds: 250));
  admin.emit("voice:start", {
    "channel": "global",
    "fromId": admin.id,
    "fromName": "Probe Admin",
  });

  await gotSecondStart.future.timeout(const Duration(seconds: 20));
  admin.emit("voice:stop");
  await Future<void>.delayed(const Duration(milliseconds: 250));
  admin.emit("voice:start", {
    "channel": "private",
    "toDriverId": driverSocketId,
    "fromId": admin.id,
    "fromName": "Probe Admin",
  });
  await gotPrivateStart.future.timeout(const Duration(seconds: 20));

  stdout.writeln(
    "Probe OK: servidor libera canal y acepta global + privado correctamente.",
  );

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
        .setTimeout(15000)
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
    const Duration(seconds: 30),
    onTimeout: () => throw "[$label] timeout de conexion",
  );
}
