import "dart:async";

import "package:socket_io_client/socket_io_client.dart" as io;

import "../utils/constants.dart";

class SocketService {
  io.Socket? _socket;
  final _connectionState = StreamController<bool>.broadcast();
  final Map<String, List<void Function(dynamic data)>> _listeners =
      <String, List<void Function(dynamic data)>>{};
  String? _bootstrapEvent;
  Map<String, dynamic>? _bootstrapPayload;

  Stream<bool> get connectionState => _connectionState.stream;
  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  void connect(String event, Map<String, dynamic> payload) {
    _bootstrapEvent = event;
    _bootstrapPayload = payload;

    if (_socket != null && _socket!.connected) {
      _socket!.emit(event, payload);
      return;
    }
    _socket?.dispose();
    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(["websocket", "polling"])
          .setPath(AppConstants.socketPath)
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setTimeout(12000)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) => _connectionState.add(true))
      ..onDisconnect((_) => _connectionState.add(false))
      ..onConnectError((_) => _connectionState.add(false))
      ..onError((_) => _connectionState.add(false))
      ..onReconnect((_) {
        if (_bootstrapEvent != null && _bootstrapPayload != null) {
          _socket!.emit(_bootstrapEvent!, _bootstrapPayload!);
        }
      })
      ..connect();
    _bindPersistentListeners();

    _socket!.onConnect((_) {
      if (_bootstrapEvent != null && _bootstrapPayload != null) {
        _socket!.emit(_bootstrapEvent!, _bootstrapPayload!);
      }
    });
  }

  void emit(String event, dynamic payload) {
    _socket?.emit(event, payload);
  }

  void on(String event, void Function(dynamic data) handler) {
    final handlers = _listeners.putIfAbsent(
      event,
      () => <void Function(dynamic data)>[],
    );
    if (!handlers.contains(handler)) {
      handlers.add(handler);
    }
    _socket?.on(event, handler);
  }

  void off(String event) {
    _listeners.remove(event);
    _socket?.off(event);
  }

  void _bindPersistentListeners() {
    if (_socket == null) return;
    for (final entry in _listeners.entries) {
      for (final handler in entry.value) {
        _socket!.on(entry.key, handler);
      }
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionState.add(false);
  }

  void dispose() {
    disconnect();
    _connectionState.close();
  }
}
