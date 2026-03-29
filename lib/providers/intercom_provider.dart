import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:math";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:just_audio/just_audio.dart";
import "package:permission_handler/permission_handler.dart";
import "package:vibration/vibration.dart";

import "../services/audio_capture_service.dart";
import "../services/beep_service.dart";
import "../services/socket_service.dart";

enum IntercomChannel { public, private }

class IntercomPeer {
  const IntercomPeer({
    required this.id,
    required this.name,
    this.role = "driver",
  });

  final String id;
  final String name;
  final String role;
}

class _IncomingFrame {
  const _IncomingFrame({required this.pcm, required this.sampleRate});

  final Uint8List pcm;
  final int sampleRate;
}

class IntercomProvider extends ChangeNotifier {
  IntercomProvider({
    required SocketService socketService,
    required BeepService beepService,
    required AudioCaptureService audioCaptureService,
  }) : _socketService = socketService,
       _beepService = beepService,
       _audioCaptureService = audioCaptureService {
    _subscribeSocket();
    _connectionSubscription = _socketService.connectionState.listen((
      connected,
    ) {
      if (connected) {
        _registerOnServer();
      }
    });
  }

  final SocketService _socketService;
  final BeepService _beepService;
  final AudioCaptureService _audioCaptureService;
  final AudioPlayer _incomingPlayer = AudioPlayer();

  bool _isTransmitting = false;
  bool _channelBusy = false;
  bool _isMuted = false;
  bool _pttTransitioning = false;
  bool _pendingReleaseDuringTransition = false;
  IntercomChannel _channel = IntercomChannel.public;
  String? _targetId;
  String? _selfId;
  String _selfRole = "driver";
  String _selfName = "Usuario";
  String? _activeSpeakerId;
  String? _activeSpeakerRole;
  String? _activeSpeakerName;
  String? _activeClientSessionId;
  DateTime? _pttStartedAt;
  DateTime? _lastIncomingVoiceAt;
  int _transmitSeconds = 0;
  int _lastTransmissionSeconds = 0;
  String? _lastErrorMessage;

  final List<IntercomPeer> _availableDrivers = <IntercomPeer>[];
  final ListQueue<_IncomingFrame> _incomingQueue = ListQueue<_IncomingFrame>();
  final BytesBuilder _incomingBuffer = BytesBuilder(copy: false);
  int _pendingIncomingSampleRate = 16000;
  StreamSubscription<Uint8List>? _captureSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _incomingFlushTimer;
  Timer? _pttSafetyTimer;
  Timer? _pttElapsedTimer;
  Timer? _incomingBusyGuardTimer;
  bool _drainingIncoming = false;

  bool get isTransmitting => _isTransmitting;
  bool get channelBusy => _channelBusy;
  bool get isPrivate => _channel == IntercomChannel.private;
  bool get isPublic => _channel == IntercomChannel.public;
  bool get isMuted => _isMuted;
  bool get selfIsAdmin => _selfRole == "admin";
  IntercomChannel get channel => _channel;
  String? get targetId => _targetId;
  String? get selfId => _selfId;
  String get selfRole => _selfRole;
  String get selfName => _selfName;
  int get transmitSeconds => _transmitSeconds;
  int get lastTransmissionSeconds => _lastTransmissionSeconds;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get activeSpeakerId => _activeSpeakerId;
  String? get activeSpeakerRole => _activeSpeakerRole;
  List<IntercomPeer> get availableDrivers =>
      List.unmodifiable(_availableDrivers);
  bool get shouldBlinkRed => isPrivate;
  Color get channelLightColor =>
      isPrivate ? Colors.redAccent : Colors.greenAccent;

  String? get activeSpeakerLabel {
    final id = _activeSpeakerId;
    final name = _activeSpeakerName;
    if (id == null && (name == null || name.isEmpty)) return null;
    if (name != null && name.isNotEmpty && id != null && id.isNotEmpty) {
      return "$name (#$id)";
    }
    if (name != null && name.isNotEmpty) return name;
    return id;
  }

  String? get _senderId {
    final socketId = _socketService.socketId;
    if (socketId != null && socketId.isNotEmpty) {
      return socketId;
    }
    return _selfId;
  }

  String displayNameForTarget(String? id) {
    if (id == null || id.isEmpty) return "-";
    if (id.toLowerCase() == "admin") return "admin";
    final found = _availableDrivers.where((d) => d.id == id).toList();
    if (found.isNotEmpty) {
      return "${found.first.name} (#${found.first.id})";
    }
    return id;
  }

  void setIdentity({
    required String userId,
    required bool isAdmin,
    String? name,
  }) {
    _selfId = userId;
    _selfRole = isAdmin ? "admin" : "driver";
    _selfName = (name ?? "").trim().isEmpty ? _selfName : name!.trim();
    _registerOnServer();
    notifyListeners();
  }

  void setMode({required bool private, String? targetId}) {
    final wasPrivate = isPrivate;
    _channel = private ? IntercomChannel.private : IntercomChannel.public;
    _targetId = private ? targetId : null;
    if (!wasPrivate && isPrivate) {
      unawaited(_beepService.playPrivateBeep());
    }
    notifyListeners();
  }

  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    _isMuted = muted;
    if (_isMuted) {
      _incomingQueue.clear();
      _incomingBuffer.clear();
      _incomingFlushTimer?.cancel();
      try {
        await _incomingPlayer.stop();
      } catch (_) {
        // Keep mute operation resilient.
      }
    }
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!_isMuted);

  Future<void> pressPtt() async {
    if (_pttTransitioning || _isTransmitting) {
      await _beepService.playBusyBeep();
      return;
    }

    if (_channelBusy) {
      final senderId = _senderId;
      final busyFromOther =
          _activeSpeakerId != null &&
          _activeSpeakerId != _selfId &&
          _activeSpeakerId != senderId;
      final staleBusy =
          _lastIncomingVoiceAt == null ||
          DateTime.now().difference(_lastIncomingVoiceAt!).inSeconds >= 2;
      if (busyFromOther && !staleBusy) {
        await _beepService.playBusyBeep();
        return;
      }
      _clearIncomingSpeaker();
    }

    if (isPrivate && (_targetId == null || _targetId!.isEmpty)) {
      await _beepService.playPttOff();
      return;
    }
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final requested = await Permission.microphone.request();
      if (!requested.isGranted && !requested.isLimited) {
        _lastErrorMessage = "Permiso de microfono no concedido";
        notifyListeners();
        await _beepService.playPttOff();
        return;
      }
    }

    _pttTransitioning = true;
    _pendingReleaseDuringTransition = false;
    final sessionId = _nextClientSessionId();
    _activeClientSessionId = sessionId;
    var captureStarted = false;

    try {
      await _audioCaptureService.start();
      captureStarted = true;

      _isTransmitting = true;
      _transmitSeconds = 0;
      _lastTransmissionSeconds = 0;
      _pttStartedAt = DateTime.now();
      _lastErrorMessage = null;
      notifyListeners();

      await _beepService.playPttOn();
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 35, amplitude: 110);
      }

      // Defensive reset for stale locks in backend before opening a new burst.
      _socketService.emit("voice:stop", _stopPayload(sessionId));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      _socketService.emit("voice:start", _startPayload(sessionId));

      _pttElapsedTimer?.cancel();
      _pttElapsedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final start = _pttStartedAt;
        if (start == null) return;
        _transmitSeconds = DateTime.now().difference(start).inSeconds;
        notifyListeners();
      });

      _captureSubscription = _audioCaptureService.chunks.listen(
        (chunk) {
          _socketService.emit("voice:chunk", _chunkPayload(chunk, sessionId));
        },
        onError: (error) {
          _lastErrorMessage = "Error de audio: ${_errorLabel(error)}";
          notifyListeners();
          unawaited(releasePtt());
        },
      );

      _pttSafetyTimer?.cancel();
      _pttSafetyTimer = Timer(const Duration(seconds: 45), () {
        unawaited(releasePtt());
      });
    } catch (e) {
      if (captureStarted) {
        try {
          await _audioCaptureService.stop();
        } catch (_) {
          // Ignore stop errors on failed start flow.
        }
      }
      _isTransmitting = false;
      _transmitSeconds = 0;
      _pttStartedAt = null;
      _activeClientSessionId = null;
      final pluginError = _audioCaptureService.lastStartError;
      _lastErrorMessage =
          "No se pudo iniciar captura de audio: ${_errorLabel(pluginError ?? e)}";
      notifyListeners();
      await _beepService.playPttOff();
    } finally {
      _pttTransitioning = false;
      if (_pendingReleaseDuringTransition && _isTransmitting) {
        _pendingReleaseDuringTransition = false;
        unawaited(releasePtt());
      }
    }
  }

  Future<void> releasePtt() async {
    if (_pttTransitioning) {
      _pendingReleaseDuringTransition = true;
      return;
    }
    if (!_isTransmitting) return;

    _pttTransitioning = true;
    _pendingReleaseDuringTransition = false;
    _pttSafetyTimer?.cancel();
    _pttSafetyTimer = null;

    final sessionId = _activeClientSessionId;
    try {
      await _captureSubscription?.cancel();
      _captureSubscription = null;
      _pttElapsedTimer?.cancel();
      _pttElapsedTimer = null;

      final start = _pttStartedAt;
      if (start != null) {
        _lastTransmissionSeconds = DateTime.now().difference(start).inSeconds;
      } else {
        _lastTransmissionSeconds = _transmitSeconds;
      }
      _pttStartedAt = null;
      _transmitSeconds = 0;

      try {
        await _audioCaptureService.stop();
      } catch (_) {
        // Ensure stop event is still emitted.
      }

      _socketService.emit("voice:stop", _stopPayload(sessionId));
      _socketService.emit("voice:end", _stopPayload(sessionId));
      await _beepService.playPttOff();
    } finally {
      _isTransmitting = false;
      _activeClientSessionId = null;
      notifyListeners();
      _pttTransitioning = false;
    }
  }

  void _registerOnServer() {
    final id = _senderId;
    if (id == null || id.isEmpty) return;
    _socketService.emit("register", {
      "role": selfIsAdmin ? "admin" : "driver",
      "name": _selfName,
      "id": id,
    });
    _socketService.emit("drivers:request", {});
  }

  Map<String, dynamic> _startPayload(String sessionId) {
    final private = isPrivate;
    final senderId = _senderId;
    return {
      "channel": private ? "private" : "global",
      "channelNumber": private ? 2 : 1,
      "private": private,
      "toDriverId": private ? _targetId : null,
      "targetId": private ? _targetId : null,
      "fromId": senderId,
      "fromName": _selfName,
      "senderId": senderId,
      "senderRole": _selfRole,
      "senderName": _selfName,
      "sampleRate": _audioCaptureService.sampleRate,
      "clientSessionId": sessionId,
    };
  }

  Map<String, dynamic> _chunkPayload(Uint8List chunk, String sessionId) {
    final private = isPrivate;
    final senderId = _senderId;
    return {
      "payload": chunk.toList(),
      "channel": private ? "private" : "global",
      "channelNumber": private ? 2 : 1,
      "private": private,
      "toDriverId": private ? _targetId : null,
      "targetId": private ? _targetId : null,
      "fromId": senderId,
      "fromName": _selfName,
      "senderId": senderId,
      "senderRole": _selfRole,
      "senderName": _selfName,
      "sampleRate": _audioCaptureService.sampleRate,
      "clientSessionId": sessionId,
    };
  }

  Map<String, dynamic> _stopPayload(String? sessionId) {
    final private = isPrivate;
    final senderId = _senderId;
    return {
      "channel": private ? "private" : "global",
      "channelNumber": private ? 2 : 1,
      "private": private,
      "toDriverId": private ? _targetId : null,
      "targetId": private ? _targetId : null,
      "fromId": senderId,
      "fromName": _selfName,
      "senderId": senderId,
      "senderRole": _selfRole,
      "senderName": _selfName,
      "sampleRate": _audioCaptureService.sampleRate,
      "clientSessionId": sessionId,
    };
  }

  void _subscribeSocket() {
    _socketService.on("drivers:list", (payload) {
      if (payload is! List) return;
      final parsed = <IntercomPeer>[];
      for (final item in payload) {
        if (item is! Map) continue;
        final id = _stringOrNull(item["id"]);
        if (id == null || id == _selfId) continue;
        final name = _stringOrNull(item["name"]) ?? "Driver";
        parsed.add(IntercomPeer(id: id, name: name, role: "driver"));
      }
      _availableDrivers
        ..clear()
        ..addAll(parsed);
      notifyListeners();
    });

    _socketService.on("voice:start", (payload) {
      final data = _asMap(payload);
      if (data == null || !_canHandleIncoming(data)) return;
      _markIncomingSpeaker(data);
      _touchIncomingVoice();
      if (_isPrivateSignal(data)) {
        unawaited(_beepService.playPrivateBeep());
      }
      notifyListeners();
    });

    void onVoiceStop(dynamic payload) {
      final data = _asMap(payload);
      if (data != null && !_canHandleIncoming(data)) return;
      _clearIncomingSpeaker(notify: true);
    }

    _socketService.on("voice:end", onVoiceStop);
    _socketService.on("voice:stop", onVoiceStop);

    _socketService.on("voice:chunk", (payload) {
      final data = _asMap(payload);
      if (data != null) {
        if (!_canHandleIncoming(data)) return;
        final bytes = _extractBytes(
          data["payload"] ?? data["chunk"] ?? data["data"],
        );
        if (bytes == null || bytes.isEmpty) return;
        final sampleRate = _resolveSampleRate(data["sampleRate"]);
        _markIncomingSpeaker(data);
        _touchIncomingVoice();
        _queueIncoming(bytes, sampleRate: sampleRate);
        notifyListeners();
        return;
      }

      final bytes = _extractBytes(payload);
      if (bytes == null || bytes.isEmpty) return;
      _touchIncomingVoice();
      _queueIncoming(bytes, sampleRate: 16000);
      notifyListeners();
    });
  }

  void _markIncomingSpeaker(Map<dynamic, dynamic> data) {
    _activeSpeakerId = _stringOrNull(
      data["senderId"] ?? data["fromId"] ?? data["id"],
    );
    _activeSpeakerRole = _stringOrNull(
      data["senderRole"] ?? data["fromRole"] ?? data["role"],
    );
    _activeSpeakerName = _stringOrNull(
      data["senderName"] ?? data["fromName"] ?? data["name"],
    );
    _channelBusy = true;
  }

  void _touchIncomingVoice() {
    _lastIncomingVoiceAt = DateTime.now();
    _incomingBusyGuardTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final last = _lastIncomingVoiceAt;
      if (last == null) return;
      final idleFor = DateTime.now().difference(last);
      if (idleFor < const Duration(seconds: 2)) return;
      _clearIncomingSpeaker(notify: true);
    });
  }

  void _clearIncomingSpeaker({bool notify = false}) {
    _channelBusy = false;
    _activeSpeakerId = null;
    _activeSpeakerRole = null;
    _activeSpeakerName = null;
    _lastIncomingVoiceAt = null;
    _incomingBusyGuardTimer?.cancel();
    _incomingBusyGuardTimer = null;
    if (notify) notifyListeners();
  }

  Map<dynamic, dynamic>? _asMap(dynamic payload) {
    if (payload is Map) return payload;
    return null;
  }

  bool _canHandleIncoming(Map<dynamic, dynamic> data) {
    if (_isTransmitting) {
      return false;
    }

    final sessionId = _stringOrNull(data["clientSessionId"]);
    if (sessionId != null &&
        _activeClientSessionId != null &&
        sessionId == _activeClientSessionId) {
      return false;
    }

    final senderId = _stringOrNull(data["senderId"] ?? data["fromId"]);
    final currentSenderId = _senderId;
    final socketId = _socketService.socketId;
    if (senderId != null &&
        (senderId == _selfId ||
            senderId == currentSenderId ||
            (socketId != null && senderId == socketId))) {
      return false;
    }

    if (!_isPrivateSignal(data)) {
      return true;
    }

    final targetId = _stringOrNull(
      data["targetId"] ?? data["toId"] ?? data["toDriverId"],
    );
    if (targetId == null || targetId.isEmpty) {
      return false;
    }
    if (_selfId != null && targetId == _selfId) return true;
    if (currentSenderId != null && targetId == currentSenderId) return true;
    if (socketId != null && targetId == socketId) return true;
    if (targetId.toLowerCase() == "admin" && selfIsAdmin) return true;
    if (targetId.toLowerCase() == "driver" && !selfIsAdmin) return true;
    return false;
  }

  bool _isPrivateSignal(Map<dynamic, dynamic> data) {
    final explicitPrivate = data["private"] == true;
    final channel = data["channel"]?.toString().toLowerCase();
    final numericChannel = data["channelNumber"] ?? data["channel"];
    final number = numericChannel is num ? numericChannel.toInt() : null;
    if (explicitPrivate) return true;
    if (channel == "private") return true;
    if (number == 2) return true;
    return false;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return str;
  }

  Uint8List? _extractBytes(dynamic raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    if (raw is List) {
      final ints = <int>[];
      for (final v in raw) {
        if (v is num) ints.add(v.toInt().clamp(0, 255).toInt());
      }
      return ints.isEmpty ? null : Uint8List.fromList(ints);
    }
    if (raw is String) {
      try {
        return base64Decode(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int _resolveSampleRate(dynamic raw) {
    final parsed = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? "");
    if (parsed == null) return 16000;
    return parsed.clamp(8000, 48000);
  }

  void _queueIncoming(Uint8List bytes, {required int sampleRate}) {
    if (_isMuted) return;
    _pendingIncomingSampleRate = sampleRate;
    _incomingBuffer.add(bytes);
    _incomingFlushTimer?.cancel();
    _incomingFlushTimer = Timer(const Duration(milliseconds: 35), () {
      final frame = _incomingBuffer.takeBytes();
      if (frame.isEmpty) return;
      _incomingQueue.add(
        _IncomingFrame(
          pcm: Uint8List.fromList(frame),
          sampleRate: _pendingIncomingSampleRate,
        ),
      );
      if (_incomingQueue.length > 8) {
        while (_incomingQueue.length > 5) {
          _incomingQueue.removeFirst();
        }
      }
      unawaited(_drainIncomingQueue());
    });
  }

  Future<void> _drainIncomingQueue() async {
    if (_drainingIncoming || _isMuted) return;
    _drainingIncoming = true;
    while (_incomingQueue.isNotEmpty && !_isMuted) {
      final frame = _incomingQueue.removeFirst();
      final wav = _pcmToWav8BitMono(frame.pcm, sampleRate: frame.sampleRate);
      final uri = Uri.dataFromBytes(wav, mimeType: "audio/wav");
      try {
        await _incomingPlayer.stop();
        await _incomingPlayer.setAudioSource(AudioSource.uri(uri));
        await _incomingPlayer.play();
      } catch (_) {
        // Continue with next frame on decode/playback failures.
      }
    }
    _drainingIncoming = false;
  }

  Uint8List _pcmToWav8BitMono(Uint8List pcm, {required int sampleRate}) {
    final dataLength = pcm.length;
    final fileSize = 36 + dataLength;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646, Endian.big) // RIFF
      ..setUint32(4, fileSize, Endian.little)
      ..setUint32(8, 0x57415645, Endian.big) // WAVE
      ..setUint32(12, 0x666d7420, Endian.big) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little) // PCM
      ..setUint16(22, 1, Endian.little) // mono
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate, Endian.little) // byteRate 8-bit mono
      ..setUint16(32, 1, Endian.little) // blockAlign
      ..setUint16(34, 8, Endian.little) // bitsPerSample
      ..setUint32(36, 0x64617461, Endian.big) // data
      ..setUint32(40, dataLength, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  String _nextClientSessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 20);
    return "$now-$rnd";
  }

  String _errorLabel(Object? error) {
    final text = (error ?? "desconocido").toString().trim();
    if (text.isEmpty) return "desconocido";
    return text.replaceFirst("Exception:", "").trim();
  }

  Future<void> disposeAll() async {
    _pttSafetyTimer?.cancel();
    _pttElapsedTimer?.cancel();
    _incomingBusyGuardTimer?.cancel();
    _incomingFlushTimer?.cancel();
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await releasePtt();
    _incomingBuffer.clear();
    _incomingQueue.clear();
    await _incomingPlayer.dispose();
    _audioCaptureService.dispose();
    await _beepService.dispose();
  }

  @override
  void dispose() {
    unawaited(disposeAll());
    super.dispose();
  }
}
