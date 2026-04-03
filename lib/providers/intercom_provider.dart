import "dart:async";

import "package:flutter/material.dart";
import "package:vibration/vibration.dart";

import "driver_provider.dart";
import "../services/beep_service.dart";
import "../services/livekit_intercom_service.dart";
import "../utils/constants.dart";
import "../utils/helpers.dart";

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

class IntercomProvider extends ChangeNotifier {
  IntercomProvider({
    required DriverProvider driverProvider,
    required BeepService beepService,
    required LiveKitIntercomService liveKitService,
  }) : _driverProvider = driverProvider,
       _beepService = beepService,
       _liveKitService = liveKitService {
    _liveKitSubscription = _liveKitService.events.listen(_handleLiveKitEvent);
  }

  final DriverProvider _driverProvider;
  final BeepService _beepService;
  final LiveKitIntercomService _liveKitService;

  final Map<int, IntercomPeer> _peerByUid = <int, IntercomPeer>{};

  StreamSubscription<LiveKitIntercomEvent>? _liveKitSubscription;
  Timer? _pttSafetyTimer;
  Timer? _pttElapsedTimer;
  Timer? _incomingBusyGuardTimer;

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
  int? _activeSpeakerUid;
  DateTime? _pttStartedAt;
  DateTime? _lastIncomingVoiceAt;
  bool _remoteSpeakerPinned = false;
  int _transmitSeconds = 0;
  int _lastTransmissionSeconds = 0;
  String? _lastErrorMessage;
  String? _joinedChannelId;
  int? _localParticipantUid;
  int? _mutedRemoteSpeakerUid;

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
  bool get shouldBlinkRed => isPrivate;
  Color get channelLightColor =>
      isPrivate ? Colors.redAccent : Colors.greenAccent;

  List<IntercomPeer> get availableDrivers => _driverProvider.drivers
      .where(
        (driver) =>
            (driver.intercomId ?? driver.id) != _participantId &&
            driver.isOnline,
      )
      .map(
        (driver) => IntercomPeer(
          id: driver.intercomId ?? driver.id,
          name: compactPersonName(driver.name),
          role: "driver",
        ),
      )
      .toList(growable: false);

  String? get activeSpeakerLabel {
    final id = _activeSpeakerId;
    final name = _activeSpeakerName;
    if (id == null && (name == null || name.isEmpty)) return null;
    if (name != null && name.isNotEmpty) return name;
    return id;
  }

  String displayNameForTarget(String? id) {
    if (id == null || id.isEmpty) return "-";
    if (id.toLowerCase() == "admin") return "Admin";
    for (final driver in _driverProvider.drivers) {
      if (driver.id == id || driver.intercomId == id) {
        return compactPersonName(driver.name);
      }
    }
    return id;
  }

  void setIdentity({
    required String userId,
    required bool isAdmin,
    String? name,
  }) {
    _selfId = isAdmin ? "admin" : userId;
    _selfRole = isAdmin ? "admin" : "driver";
    _selfName = (name ?? "").trim().isEmpty ? _selfName : name!.trim();
    _rememberSelfPeer();
    unawaited(_syncChannelMembership(force: true));
    notifyListeners();
  }

  String get _effectiveSelfId {
    final ownId = (_selfId ?? "").trim();
    if (selfIsAdmin) {
      return "admin";
    }
    return ownId.isEmpty ? "driver" : ownId;
  }

  String get _effectiveSelfName {
    final providerName = _driverProvider.self?.name.trim();
    if (!selfIsAdmin && providerName != null && providerName.isNotEmpty) {
      return compactPersonName(providerName);
    }
    return compactPersonName(_selfName);
  }

  void setMode({required bool private, String? targetId}) {
    final nextChannel = private
        ? IntercomChannel.private
        : IntercomChannel.public;
    final nextTargetId = private ? targetId : null;
    final changed = _channel != nextChannel || _targetId != nextTargetId;
    if (!changed) return;

    if (_isTransmitting) {
      unawaited(releasePtt());
    }

    final enteringPrivate =
        _channel == IntercomChannel.public &&
        nextChannel == IntercomChannel.private;
    _channel = nextChannel;
    _targetId = nextTargetId;
    _clearIncomingSpeaker(notify: false);
    if (enteringPrivate) {
      unawaited(_beepService.playPrivateBeep());
    }
    unawaited(_syncChannelMembership(force: _joinedChannelId == null));
    notifyListeners();
  }

  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    _isMuted = muted;
    await _liveKitService.setRemoteMuted(muted);
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!_isMuted);

  Future<void> pressPtt() async {
    if (_pttTransitioning || _isTransmitting) {
      await _beepService.playBusyBeep();
      return;
    }

    if (isPrivate && (_targetId == null || _targetId!.isEmpty)) {
      await _beepService.playPttOff();
      return;
    }

    if (_selfId == null || _selfId!.isEmpty) {
      _lastErrorMessage = "Inicia sesion antes de usar intercom";
      notifyListeners();
      await _beepService.playPttOff();
      return;
    }

    if (_hasRemoteSpeakerLocked()) {
      await _beepService.playBusyBeep();
      return;
    }

    _pttTransitioning = true;
    _pendingReleaseDuringTransition = false;
    try {
      await _syncChannelMembership(force: false);
      final channelId = _resolvedIntercomChannelId();
      if (channelId == null || _joinedChannelId != channelId) {
        throw StateError("No se pudo enlazar el canal actual");
      }

      await _liveKitService.refreshAudioPipeline();
      await _liveKitService.sendSignal(_signalPayload(type: "ptt-start"));
      await _liveKitService.startPublishing();

      _isTransmitting = true;
      _transmitSeconds = 0;
      _lastTransmissionSeconds = 0;
      _pttStartedAt = DateTime.now();
      _lastErrorMessage = null;
      _setSelfAsActiveSpeaker();
      notifyListeners();

      await _beepService.playPttOn();
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 35, amplitude: 110);
      }

      _pttElapsedTimer?.cancel();
      _pttElapsedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final start = _pttStartedAt;
        if (start == null) return;
        _transmitSeconds = DateTime.now().difference(start).inSeconds;
        notifyListeners();
      });

      _pttSafetyTimer?.cancel();
      _pttSafetyTimer = Timer(const Duration(seconds: 90), () {
        unawaited(releasePtt());
      });
    } catch (error) {
      _isTransmitting = false;
      _transmitSeconds = 0;
      _pttStartedAt = null;
      _clearIncomingSpeaker(notify: false);
      _lastErrorMessage = "No se pudo iniciar intercom: ${_errorLabel(error)}";
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
    _pttElapsedTimer?.cancel();
    _pttElapsedTimer = null;

    try {
      final start = _pttStartedAt;
      if (start != null) {
        _lastTransmissionSeconds = DateTime.now().difference(start).inSeconds;
      } else {
        _lastTransmissionSeconds = _transmitSeconds;
      }
      _pttStartedAt = null;
      _transmitSeconds = 0;

      await _liveKitService.stopPublishing();
      await _liveKitService.sendSignal(_signalPayload(type: "ptt-stop"));
      await _beepService.playPttOff();
    } finally {
      _isTransmitting = false;
      if (_hasFreshIncomingVoice()) {
        _channelBusy = true;
      } else {
        _clearIncomingSpeaker(notify: false);
      }
      notifyListeners();
      _pttTransitioning = false;
    }
  }

  Future<void> _syncChannelMembership({bool force = false}) async {
    if (_selfId == null || _selfId!.trim().isEmpty) return;

    final channelId = _resolvedIntercomChannelId();
    if (channelId == null || channelId.isEmpty) return;

    final localUid = _resolveLocalParticipantUid();
    if (!force && _joinedChannelId == channelId && _liveKitService.isJoined) {
      await _liveKitService.setRemoteMuted(_isMuted);
      return;
    }

    try {
      await _liveKitService.ensureJoined(
        channelId: channelId,
        participantIdentity: _participantId,
        participantName: _effectiveSelfName,
        participantRole: _selfRole,
      );
      _joinedChannelId = channelId;
      _localParticipantUid = _liveKitService.localUid ?? localUid;
      _rememberSelfPeer();
      await _liveKitService.refreshAudioPipeline();
      await _liveKitService.setRemoteMuted(_isMuted);
      await _liveKitService.sendSignal(_signalPayload(type: "presence"));
      _lastErrorMessage = null;
      notifyListeners();
    } catch (error) {
      _lastErrorMessage = "LiveKit no pudo conectar: ${_errorLabel(error)}";
      notifyListeners();
    }
  }

  void _handleLiveKitEvent(LiveKitIntercomEvent event) {
    switch (event.type) {
      case LiveKitIntercomEventType.joined:
        _joinedChannelId = event.channelId;
        _localParticipantUid = event.uid;
        _rememberSelfPeer();
        unawaited(_liveKitService.refreshAudioPipeline());
        unawaited(_liveKitService.setRemoteMuted(_isMuted));
        unawaited(_liveKitService.sendSignal(_signalPayload(type: "presence")));
        _lastErrorMessage = null;
        notifyListeners();
        return;
      case LiveKitIntercomEventType.left:
        _joinedChannelId = null;
        _localParticipantUid = null;
        _mutedRemoteSpeakerUid = null;
        if (!_isTransmitting) {
          _clearIncomingSpeaker(notify: true);
        }
        return;
      case LiveKitIntercomEventType.peerJoined:
        return;
      case LiveKitIntercomEventType.peerLeft:
        final uid = event.uid;
        if (uid == null) return;
        if (_activeSpeakerUid == uid && !_isTransmitting) {
          _clearIncomingSpeaker(notify: true);
        }
        return;
      case LiveKitIntercomEventType.audioLevel:
        final uid = event.uid;
        final volume = event.payload?["volume"] as int?;
        if (uid == null || volume == null) return;
        _handleAudioLevel(uid: uid, volume: volume);
        return;
      case LiveKitIntercomEventType.signal:
        final uid = event.uid;
        final payload = event.payload;
        if (uid == null || payload == null) return;
        _handleSignal(uid: uid, payload: payload);
        return;
      case LiveKitIntercomEventType.error:
        _lastErrorMessage = event.message;
        notifyListeners();
        return;
      case LiveKitIntercomEventType.connection:
        if (event.connected == true) {
          unawaited(_liveKitService.refreshAudioPipeline());
        }
        if (event.connected == false && !_isTransmitting) {
          _clearIncomingSpeaker(notify: true);
        }
        if ((event.message ?? "").trim().isNotEmpty &&
            event.connected == false) {
          _lastErrorMessage = event.message;
          notifyListeners();
        }
        return;
    }
  }

  void _handleAudioLevel({required int uid, required int volume}) {
    final localUid = _localParticipantUid;
    if (localUid != null && uid == localUid) {
      if (_isTransmitting) {
        _channelBusy = true;
        notifyListeners();
      }
      return;
    }
    if (volume < 8) return;
    _markRemoteSpeaker(uid: uid);
    _touchIncomingVoice();
    notifyListeners();
  }

  void _handleSignal({
    required int uid,
    required Map<String, dynamic> payload,
  }) {
    final messageChannel = _stringOrNull(payload["channelId"]);
    if (messageChannel != null &&
        _joinedChannelId != null &&
        messageChannel != _joinedChannelId) {
      return;
    }

    _rememberPeer(
      uid: uid,
      id: _stringOrNull(payload["speakerId"]),
      name: _stringOrNull(payload["speakerName"]),
      role: _stringOrNull(payload["speakerRole"]),
    );

    final type = _stringOrNull(payload["type"]);
    switch (type) {
      case "presence":
        unawaited(
          _liveKitService.sendSignal(_signalPayload(type: "presence-ack")),
        );
        return;
      case "presence-ack":
        return;
      case "ptt-start":
        unawaited(_applySpeakerRouting(uid: uid, payload: payload));
        unawaited(_liveKitService.refreshAudioPipeline());
        _remoteSpeakerPinned = true;
        _markRemoteSpeaker(
          uid: uid,
          id: _stringOrNull(payload["speakerId"]),
          name: _stringOrNull(payload["speakerName"]),
          role: _stringOrNull(payload["speakerRole"]),
        );
        _touchIncomingVoice();
        if (payload["channelNumber"] == 2 || payload["private"] == true) {
          unawaited(_beepService.playPrivateBeep());
        }
        notifyListeners();
        return;
      case "ptt-stop":
        unawaited(_liveKitService.clearRemoteUserMutes());
        _mutedRemoteSpeakerUid = null;
        _remoteSpeakerPinned = false;
        if (_activeSpeakerUid == uid && !_isTransmitting) {
          _clearIncomingSpeaker(notify: true);
        } else {
          notifyListeners();
        }
        return;
    }
  }

  Future<void> _applySpeakerRouting({
    required int uid,
    required Map<String, dynamic> payload,
  }) async {
    final shouldHear = _shouldHearPayload(payload);
    if (shouldHear) {
      if (_mutedRemoteSpeakerUid == uid) {
        await _liveKitService.muteRemoteUser(uid, false);
        _mutedRemoteSpeakerUid = null;
      }
      return;
    }

    await _liveKitService.muteRemoteUser(uid, true);
    _mutedRemoteSpeakerUid = uid;
  }

  bool _shouldHearPayload(Map<String, dynamic> payload) {
    if (_isMuted) return false;
    final privateFlag =
        payload["private"] == true ||
        payload["channelNumber"] == 2 ||
        _stringOrNull(payload["channel"]) == "private";
    if (!privateFlag) return true;

    final target = _stringOrNull(payload["targetId"])?.toLowerCase();
    final self = _participantId.toLowerCase();
    if (selfIsAdmin) {
      return target == "admin";
    }
    return target == self;
  }

  void _markRemoteSpeaker({
    required int uid,
    String? id,
    String? name,
    String? role,
  }) {
    final peer = _resolvePeerForUid(uid);
    _activeSpeakerUid = uid;
    _activeSpeakerId = id ?? peer?.id ?? "UID $uid";
    _activeSpeakerName = name ?? peer?.name;
    _activeSpeakerRole = role ?? peer?.role;
    _channelBusy = true;
  }

  void _touchIncomingVoice() {
    _lastIncomingVoiceAt = DateTime.now();
    _incomingBusyGuardTimer ??= Timer.periodic(
      const Duration(milliseconds: 800),
      (_) {
        if (_isTransmitting) return;
        if (_remoteSpeakerPinned) return;
        if (_hasFreshIncomingVoice()) return;
        _clearIncomingSpeaker(notify: true);
      },
    );
  }

  bool _hasFreshIncomingVoice() {
    final last = _lastIncomingVoiceAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(milliseconds: 1400);
  }

  bool _hasRemoteSpeakerLocked() {
    if (!_channelBusy) return false;
    if (_activeSpeakerUid == null) return false;
    if (_localParticipantUid != null &&
        _activeSpeakerUid == _localParticipantUid) {
      return false;
    }
    if (_remoteSpeakerPinned) return true;
    return _hasFreshIncomingVoice();
  }

  void _setSelfAsActiveSpeaker() {
    _activeSpeakerUid = _localParticipantUid ?? _resolveLocalParticipantUid();
    _activeSpeakerId = _participantId;
    _activeSpeakerName = _effectiveSelfName;
    _activeSpeakerRole = _selfRole;
    _channelBusy = true;
  }

  void _clearIncomingSpeaker({bool notify = false}) {
    _channelBusy = false;
    _remoteSpeakerPinned = false;
    _activeSpeakerUid = null;
    _activeSpeakerId = null;
    _activeSpeakerRole = null;
    _activeSpeakerName = null;
    _mutedRemoteSpeakerUid = null;
    _lastIncomingVoiceAt = null;
    _incomingBusyGuardTimer?.cancel();
    _incomingBusyGuardTimer = null;
    unawaited(_liveKitService.clearRemoteUserMutes());
    if (notify) notifyListeners();
  }

  Map<String, dynamic> _signalPayload({required String type}) {
    final privateChannel = isPrivate;
    return {
      "type": type,
      "channelId": _resolvedIntercomChannelId(),
      "channel": privateChannel ? "private" : "public",
      "channelNumber": privateChannel ? 2 : 1,
      "private": privateChannel,
      "targetId": privateChannel ? _resolvedPrivateTargetId() : null,
      "speakerId": _participantId,
      "speakerName": _effectiveSelfName,
      "speakerRole": _selfRole,
      "timestamp": DateTime.now().toIso8601String(),
    };
  }

  String? _resolvedIntercomChannelId() {
    return AppConstants.liveKitRoomName;
  }

  String? _resolvedPrivateTargetId() {
    if (isPublic) return null;
    if (selfIsAdmin) return _targetId;
    return "admin";
  }

  String get _participantId {
    return _effectiveSelfId;
  }

  int _resolveLocalParticipantUid() {
    if (selfIsAdmin) return 900000001;
    return _driverParticipantUid(_effectiveSelfId);
  }

  int _driverParticipantUid(String seed) {
    var hash = 0x811C9DC5;
    for (final code in "driver:$seed".codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 100000 + (hash % 800000000);
  }

  IntercomPeer? _resolvePeerForUid(int uid) {
    final remembered = _peerByUid[uid];
    if (remembered != null) return remembered;

    if (_localParticipantUid != null && uid == _localParticipantUid) {
      return IntercomPeer(
        id: _participantId,
        name: _effectiveSelfName,
        role: _selfRole,
      );
    }
    if (uid == 900000001) {
      return const IntercomPeer(id: "admin", name: "Admin", role: "admin");
    }
    for (final driver in _driverProvider.drivers) {
      final intercomId = driver.intercomId ?? driver.id;
      if (_driverParticipantUid(intercomId) == uid) {
        final peer = IntercomPeer(
          id: intercomId,
          name: compactPersonName(driver.name),
          role: "driver",
        );
        _peerByUid[uid] = peer;
        return peer;
      }
    }
    return null;
  }

  void _rememberSelfPeer() {
    final localUid = _localParticipantUid ?? _resolveLocalParticipantUid();
    _peerByUid[localUid] = IntercomPeer(
      id: _participantId,
      name: _effectiveSelfName,
      role: _selfRole,
    );
  }

  void _rememberPeer({
    required int uid,
    String? id,
    String? name,
    String? role,
  }) {
    final current = _peerByUid[uid];
    final nextId = id ?? current?.id ?? "UID $uid";
    final nextName = name ?? current?.name ?? nextId;
    final nextRole = role ?? current?.role ?? "driver";
    _peerByUid[uid] = IntercomPeer(id: nextId, name: nextName, role: nextRole);
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
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
    await _liveKitSubscription?.cancel();
    _liveKitSubscription = null;
    await releasePtt();
    await _liveKitService.dispose();
    await _beepService.dispose();
  }

  @override
  void dispose() {
    unawaited(disposeAll());
    super.dispose();
  }
}
