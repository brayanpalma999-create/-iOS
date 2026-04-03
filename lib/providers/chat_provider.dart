import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../models/chat_message_model.dart";
import "../services/socket_service.dart";
import "../utils/helpers.dart";
import "driver_provider.dart";

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required SocketService socketService,
    required DriverProvider driverProvider,
  }) : _socketService = socketService,
       _driverProvider = driverProvider {
    _bindSocket();
  }

  final SocketService _socketService;
  final DriverProvider _driverProvider;
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessageModel> _messages = <ChatMessageModel>[];
  static const String groupConversationId = "fleet::global";

  bool _listenersBound = false;
  String? _selfId;
  String _selfName = "Usuario";
  String _selfRole = "driver";
  String? _lastError;

  String? get lastError => _lastError;
  bool get selfIsAdmin => _selfRole == "admin";
  List<ChatMessageModel> get groupMessages {
    final matches =
        _messages
            .where((message) => message.conversationId == groupConversationId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return matches;
  }

  int get groupMessageCount => groupMessages.length;

  void setIdentity({
    required String userId,
    required String name,
    required bool isAdmin,
  }) {
    _selfId = userId;
    _selfName = name.trim().isEmpty ? _selfName : name.trim();
    _selfRole = isAdmin ? "admin" : "driver";
    notifyListeners();
  }

  void clearSession() {
    _selfId = null;
    _selfName = "Usuario";
    _selfRole = "driver";
    _lastError = null;
    _messages.clear();
    notifyListeners();
  }

  List<ChatMessageModel> messagesForConversation(String driverId) {
    final conversationId = conversationIdFor(driverId);
    final matches =
        _messages
            .where((message) => message.conversationId == conversationId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return matches;
  }

  ChatMessageModel? latestForConversation(String driverId) {
    final items = messagesForConversation(driverId);
    if (items.isEmpty) return null;
    return items.last;
  }

  int countForConversation(String driverId) =>
      messagesForConversation(driverId).length;

  bool isMine(ChatMessageModel message) =>
      message.senderRole == _selfRole && message.senderId == _effectiveSelfId;

  Future<void> sendText({
    required String driverId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _emitMessage(
      driverId: driverId,
      text: normalized,
      imageBase64: null,
      imageMimeType: null,
    );
  }

  Future<void> sendGroupText({required String text}) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    _emitGroupMessage(text: normalized, imageBase64: null, imageMimeType: null);
  }

  Future<void> sendPhoto({required String driverId}) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 74,
        maxWidth: 1440,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final encoded = base64Encode(bytes);
      _emitMessage(
        driverId: driverId,
        text: "",
        imageBase64: encoded,
        imageMimeType: _mimeForPath(picked),
      );
    } catch (_) {
      _lastError = "No se pudo adjuntar la foto";
      notifyListeners();
    }
  }

  Future<void> sendGroupPhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 74,
        maxWidth: 1440,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final encoded = base64Encode(bytes);
      _emitGroupMessage(
        text: "",
        imageBase64: encoded,
        imageMimeType: _mimeForPath(picked),
      );
    } catch (_) {
      _lastError = "No se pudo adjuntar la foto";
      notifyListeners();
    }
  }

  String conversationIdFor(String driverId) => "admin::$driverId";

  String driverIdForConversation(ChatMessageModel message) {
    if (message.conversationId.startsWith("admin::")) {
      return message.conversationId.replaceFirst("admin::", "");
    }
    return message.senderRole == "driver" ? message.senderId : message.targetId;
  }

  void _emitGroupMessage({
    required String text,
    required String? imageBase64,
    required String? imageMimeType,
  }) {
    final senderId = _effectiveSelfId;
    final senderName = _effectiveSelfName;
    if (senderId.isEmpty) {
      _lastError = "Inicia sesion antes de usar inbox";
      notifyListeners();
      return;
    }

    _lastError = null;
    _socketService.emit("chat:send", {
      "id": DateTime.now().microsecondsSinceEpoch.toString(),
      "senderId": senderId,
      "senderName": senderName,
      "senderRole": _selfRole,
      "targetId": "all",
      "driverId": _selfRole == "driver" ? senderId : null,
      "chatScope": "global",
      "conversationId": groupConversationId,
      "text": text,
      "imageBase64": imageBase64,
      "imageMimeType": imageMimeType,
      "createdAt": DateTime.now().toIso8601String(),
    });
  }

  void _emitMessage({
    required String driverId,
    required String text,
    required String? imageBase64,
    required String? imageMimeType,
  }) {
    final senderId = _effectiveSelfId;
    final senderName = _effectiveSelfName;
    if (senderId.isEmpty) {
      _lastError = "Inicia sesion antes de usar inbox";
      notifyListeners();
      return;
    }

    _lastError = null;
    _socketService.emit("chat:send", {
      "id": DateTime.now().microsecondsSinceEpoch.toString(),
      "senderId": senderId,
      "senderName": senderName,
      "senderRole": _selfRole,
      "targetId": selfIsAdmin ? driverId : "admin",
      "driverId": driverId,
      "conversationId": conversationIdFor(driverId),
      "text": text,
      "imageBase64": imageBase64,
      "imageMimeType": imageMimeType,
      "createdAt": DateTime.now().toIso8601String(),
    });
  }

  void _bindSocket() {
    if (_listenersBound) return;
    _listenersBound = true;
    _socketService.on("chat:message", (payload) {
      final message = _parseMessage(payload);
      if (message == null) return;
      final index = _messages.indexWhere((item) => item.id == message.id);
      if (index >= 0) {
        _messages[index] = message;
      } else {
        _messages.add(message);
      }
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    });
  }

  ChatMessageModel? _parseMessage(dynamic payload) {
    if (payload is! Map) return null;
    final map = <String, dynamic>{};
    for (final entry in payload.entries) {
      map[entry.key.toString()] = entry.value;
    }
    final message = ChatMessageModel.fromJson(map);
    if (message.conversationId.isEmpty) return null;
    return message;
  }

  String get _effectiveSelfId {
    if (selfIsAdmin) {
      return (_selfId ?? "").trim();
    }
    final driverId = _driverProvider.self?.id.trim();
    if (driverId != null && driverId.isNotEmpty) return driverId;
    return (_selfId ?? "").trim();
  }

  String get _effectiveSelfName {
    if (selfIsAdmin) return compactPersonName(_selfName);
    final driverName = _driverProvider.self?.name.trim();
    if (driverName != null && driverName.isNotEmpty) {
      return compactPersonName(driverName);
    }
    return compactPersonName(_selfName);
  }

  String _mimeForPath(XFile file) {
    final path = file.path.toLowerCase();
    if (path.endsWith(".png")) return "image/png";
    if (path.endsWith(".webp")) return "image/webp";
    return "image/jpeg";
  }
}
