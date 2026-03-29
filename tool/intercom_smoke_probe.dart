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

  await _waitConnected(admin, "admin");
  await _waitConnected(driver, "driver");

  admin.emit("register", {"role": "admin", "name": "Probe Admin"});
  driver.emit("register", {"role": "driver", "name": "Probe Driver"});

  final globalStart = Completer<void>();
  final globalStop = Completer<void>();
  final globalChunk = Completer<void>();
  final privateStart = Completer<void>();

  String? driverId;
  driver.on("connect", (_) {
    driverId = driver.id;
  });
  driverId ??= driver.id;

  driver.on("voice:start", (payload) {
    if (payload is! Map) return;
    final channel = payload["channel"]?.toString().toLowerCase() ?? "";
    if (channel == "global" && !globalStart.isCompleted) {
      globalStart.complete();
    }
    if (channel == "private" && !privateStart.isCompleted) {
      privateStart.complete();
    }
  });

  driver.on("voice:stop", (_) {
    if (!globalStop.isCompleted) {
      globalStop.complete();
    }
  });

  driver.on("voice:chunk", (payload) {
    if (payload is! Map) return;
    final channel = payload["channel"]?.toString().toLowerCase() ?? "";
    if (channel != "global") return;
    final sampleRateRaw = payload["sampleRate"];
    final sampleRate = sampleRateRaw is num
        ? sampleRateRaw.toInt()
        : int.tryParse(sampleRateRaw?.toString() ?? "");
    final bytes = payload["payload"];
    final hasBytes = bytes is List && bytes.isNotEmpty;
    if (sampleRate == 24000 && hasBytes && !globalChunk.isCompleted) {
      globalChunk.complete();
    }
  });

  final adminPayloadBase = {
    "fromId": admin.id,
    "senderId": admin.id,
    "fromName": "Probe Admin",
    "senderName": "Probe Admin",
    "senderRole": "admin",
    "clientSessionId": DateTime.now().microsecondsSinceEpoch.toString(),
  };

  admin.emit("voice:start", {
    ...adminPayloadBase,
    "channel": "global",
    "channelNumber": 1,
    "private": false,
  });
  await globalStart.future.timeout(const Duration(seconds: 8));

  admin.emit("voice:chunk", {
    ...adminPayloadBase,
    "channel": "global",
    "channelNumber": 1,
    "private": false,
    "sampleRate": 24000,
    "payload": [128, 130, 126, 132, 124, 129, 127, 131],
  });
  await globalChunk.future.timeout(const Duration(seconds: 8));

  admin.emit("voice:stop", {
    ...adminPayloadBase,
    "channel": "global",
    "channelNumber": 1,
    "private": false,
  });
  await globalStop.future.timeout(const Duration(seconds: 8));

  if (driverId == null || driverId!.isEmpty) {
    throw Exception("No se pudo resolver driverId para prueba privada");
  }

  admin.emit("voice:start", {
    ...adminPayloadBase,
    "channel": "private",
    "channelNumber": 2,
    "private": true,
    "toDriverId": driverId,
    "targetId": driverId,
  });
  await privateStart.future.timeout(const Duration(seconds: 8));

  stdout.writeln("Intercom probe OK: global y privado activos.");

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
