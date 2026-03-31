import "dart:async";
import "dart:convert";

import "package:livekit_client/livekit_client.dart";

import "../utils/constants.dart";
import "livekit_token_service.dart";

enum LiveKitIntercomEventType {
  joined,
  left,
  peerJoined,
  peerLeft,
  audioLevel,
  signal,
  error,
  connection,
}

class LiveKitIntercomEvent {
  const LiveKitIntercomEvent._({
    required this.type,
    this.uid,
    this.identity,
    this.channelId,
    this.payload,
    this.message,
    this.connected,
  });

  final LiveKitIntercomEventType type;
  final int? uid;
  final String? identity;
  final String? channelId;
  final Map<String, dynamic>? payload;
  final String? message;
  final bool? connected;

  factory LiveKitIntercomEvent.joined({
    required int uid,
    required String identity,
    required String channelId,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.joined,
    uid: uid,
    identity: identity,
    channelId: channelId,
  );

  factory LiveKitIntercomEvent.left({String? channelId}) =>
      LiveKitIntercomEvent._(
        type: LiveKitIntercomEventType.left,
        channelId: channelId,
      );

  factory LiveKitIntercomEvent.peerJoined({
    required int uid,
    required String identity,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.peerJoined,
    uid: uid,
    identity: identity,
  );

  factory LiveKitIntercomEvent.peerLeft({
    required int uid,
    required String identity,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.peerLeft,
    uid: uid,
    identity: identity,
  );

  factory LiveKitIntercomEvent.audioLevel({
    required int uid,
    required String identity,
    required int volume,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.audioLevel,
    uid: uid,
    identity: identity,
    payload: <String, dynamic>{"volume": volume},
  );

  factory LiveKitIntercomEvent.signal({
    required int uid,
    required String identity,
    required Map<String, dynamic> payload,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.signal,
    uid: uid,
    identity: identity,
    payload: payload,
  );

  factory LiveKitIntercomEvent.error(String message) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.error,
    message: message,
  );

  factory LiveKitIntercomEvent.connection({
    required bool connected,
    String? message,
    String? channelId,
  }) => LiveKitIntercomEvent._(
    type: LiveKitIntercomEventType.connection,
    connected: connected,
    message: message,
    channelId: channelId,
  );
}

class LiveKitIntercomService {
  LiveKitIntercomService({LiveKitTokenService? tokenService})
    : _tokenService = tokenService ?? LiveKitTokenService(),
      _ownsTokenService = tokenService == null;

  final StreamController<LiveKitIntercomEvent> _events =
      StreamController<LiveKitIntercomEvent>.broadcast();
  final LiveKitTokenService _tokenService;
  final bool _ownsTokenService;

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  bool _initialized = false;
  bool _joined = false;
  bool _remoteMuted = false;
  String? _joinedChannelId;
  String? _localIdentity;
  int? _localUid;
  final Map<String, int> _uidByIdentity = <String, int>{};
  final Map<int, String> _identityByUid = <int, String>{};
  final Set<String> _mutedRemoteIdentities = <String>{};

  Stream<LiveKitIntercomEvent> get events => _events.stream;
  bool get isJoined => _joined;
  String? get joinedChannelId => _joinedChannelId;
  int? get localUid => _localUid;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  Future<void> ensureJoined({
    required String channelId,
    required String participantIdentity,
    required String participantName,
    required String participantRole,
  }) async {
    await initialize();
    if (_joined &&
        _joinedChannelId == channelId &&
        _localIdentity == participantIdentity) {
      await _applyRemoteMuteState();
      return;
    }

    if (_joined) {
      await leave();
    }

    final credentials = await _tokenService.fetchJoinCredentials(
      roomName: channelId,
      identity: participantIdentity,
      name: participantName,
      role: participantRole,
    );

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          noiseSuppression: true,
          echoCancellation: true,
          autoGainControl: true,
          voiceIsolation: true,
          stopAudioCaptureOnMute: false,
        ),
      ),
    );
    _bindRoom(room);

    try {
      await room.connect(
        credentials.serverUrl,
        credentials.token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );

      _room = room;
      _joined = true;
      _joinedChannelId = credentials.roomName;
      _localIdentity = participantIdentity;
      _localUid = _participantUidForIdentity(participantIdentity);
      _rememberIdentity(identity: participantIdentity, uid: _localUid!);

      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(false);
      await _applyRemoteMuteState();

      for (final participant in room.remoteParticipants.values) {
        final identity = participant.identity;
        final uid = _participantUidForIdentity(identity);
        _rememberIdentity(identity: identity, uid: uid);
        await _applyMuteStateToIdentity(identity);
        _events.add(
          LiveKitIntercomEvent.peerJoined(uid: uid, identity: identity),
        );
      }

      _events.add(
        LiveKitIntercomEvent.joined(
          uid: _localUid!,
          identity: participantIdentity,
          channelId: credentials.roomName,
        ),
      );
      _events.add(
        LiveKitIntercomEvent.connection(
          connected: true,
          channelId: credentials.roomName,
          message: "LiveKit conectado",
        ),
      );
    } catch (_) {
      await _resetRoomState();
      rethrow;
    }
  }

  Future<void> startPublishing() async {
    final room = _room;
    if (room == null) return;
    await room.localParticipant?.setMicrophoneEnabled(true);
  }

  Future<void> stopPublishing() async {
    final room = _room;
    if (room == null) return;
    await room.localParticipant?.setMicrophoneEnabled(false);
  }

  Future<void> setRemoteMuted(bool muted) async {
    _remoteMuted = muted;
    await _applyRemoteMuteState();
  }

  Future<void> muteRemoteUser(int uid, bool muted) async {
    final identity = _identityByUid[uid];
    if (identity == null) return;
    if (muted) {
      _mutedRemoteIdentities.add(identity);
    } else {
      _mutedRemoteIdentities.remove(identity);
    }
    await _applyMuteStateToIdentity(identity);
  }

  Future<void> clearRemoteUserMutes() async {
    if (_mutedRemoteIdentities.isEmpty) return;
    final identities = _mutedRemoteIdentities.toList(growable: false);
    _mutedRemoteIdentities.clear();
    for (final identity in identities) {
      await _applyMuteStateToIdentity(identity);
    }
  }

  Future<void> sendSignal(Map<String, dynamic> payload) async {
    final room = _room;
    final localParticipant = room?.localParticipant;
    if (room == null || localParticipant == null || !_joined) return;

    final data = utf8.encode(jsonEncode(payload));
    final topic = AppConstants.liveKitSignalTopic;
    final isPrivate =
        payload["private"] == true ||
        payload["channelNumber"] == 2 ||
        payload["channel"] == "private";
    final target = _stringOrNull(payload["targetId"]);
    final destinations = isPrivate && target != null ? <String>[target] : null;

    await localParticipant.publishData(
      data,
      reliable: true,
      destinationIdentities: destinations,
      topic: topic,
    );
  }

  Future<void> leave() async {
    final room = _room;
    if (room == null) return;

    final channelId = _joinedChannelId;
    try {
      await stopPublishing();
      await room.disconnect();
    } finally {
      await _resetRoomState();
      _mutedRemoteIdentities.clear();
      _events.add(LiveKitIntercomEvent.left(channelId: channelId));
      _events.add(
        LiveKitIntercomEvent.connection(
          connected: false,
          channelId: channelId,
          message: "LiveKit desconectado",
        ),
      );
    }
  }

  Future<void> dispose() async {
    await leave();
    if (_ownsTokenService) {
      _tokenService.dispose();
    }
    await _events.close();
  }

  void _bindRoom(Room room) {
    unawaited(_roomListener?.dispose());
    final listener = room.createListener();
    listener.listen((event) async {
      await _handleRoomEvent(event);
    });
    _roomListener = listener;
  }

  Future<void> _handleRoomEvent(RoomEvent event) async {
    if (event is ParticipantConnectedEvent) {
      final identity = event.participant.identity;
      final uid = _participantUidForIdentity(identity);
      _rememberIdentity(identity: identity, uid: uid);
      await _applyMuteStateToIdentity(identity);
      _events.add(
        LiveKitIntercomEvent.peerJoined(uid: uid, identity: identity),
      );
      return;
    }

    if (event is ParticipantDisconnectedEvent) {
      final identity = event.participant.identity;
      final uid = _participantUidForIdentity(identity);
      _mutedRemoteIdentities.remove(identity);
      _events.add(LiveKitIntercomEvent.peerLeft(uid: uid, identity: identity));
      return;
    }

    if (event is ActiveSpeakersChangedEvent) {
      for (final participant in event.speakers) {
        final identity = participant.identity;
        final uid = _participantUidForIdentity(identity);
        _rememberIdentity(identity: identity, uid: uid);
        final volume = (participant.audioLevel * 100).round().clamp(0, 100);
        if (volume <= 0) continue;
        _events.add(
          LiveKitIntercomEvent.audioLevel(
            uid: uid,
            identity: identity,
            volume: volume,
          ),
        );
      }
      return;
    }

    if (event is DataReceivedEvent) {
      final participant = event.participant;
      if (participant == null) return;
      if (event.topic != AppConstants.liveKitSignalTopic) return;
      try {
        final decoded = jsonDecode(utf8.decode(event.data));
        if (decoded is Map) {
          final uid = _participantUidForIdentity(participant.identity);
          _rememberIdentity(identity: participant.identity, uid: uid);
          _events.add(
            LiveKitIntercomEvent.signal(
              uid: uid,
              identity: participant.identity,
              payload: decoded.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          );
        }
      } catch (_) {
        _events.add(
          LiveKitIntercomEvent.error("No se pudo leer senal LiveKit"),
        );
      }
      return;
    }

    if (event is RoomReconnectingEvent) {
      _events.add(
        LiveKitIntercomEvent.connection(
          connected: false,
          channelId: _joinedChannelId,
          message: "LiveKit reconectando",
        ),
      );
      return;
    }

    if (event is RoomReconnectedEvent) {
      _events.add(
        LiveKitIntercomEvent.connection(
          connected: true,
          channelId: _joinedChannelId,
          message: "LiveKit reconectado",
        ),
      );
      await _applyRemoteMuteState();
      return;
    }

    if (event is RoomDisconnectedEvent) {
      final channelId = _joinedChannelId;
      await _resetRoomState();
      _events.add(
        LiveKitIntercomEvent.error(
          "LiveKit desconectado: ${event.reason?.name ?? "desconocido"}",
        ),
      );
      _events.add(LiveKitIntercomEvent.left(channelId: channelId));
      _events.add(
        LiveKitIntercomEvent.connection(
          connected: false,
          channelId: channelId,
          message: "LiveKit desconectado",
        ),
      );
      return;
    }
  }

  Future<void> _resetRoomState() async {
    await _roomListener?.dispose();
    _roomListener = null;
    _room = null;
    _joined = false;
    _joinedChannelId = null;
    _localIdentity = null;
    _localUid = null;
    _uidByIdentity.clear();
    _identityByUid.clear();
  }

  Future<void> _applyRemoteMuteState() async {
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      await _applyMuteStateToIdentity(participant.identity);
    }
  }

  Future<void> _applyMuteStateToIdentity(String identity) async {
    final room = _room;
    if (room == null) return;
    final participant = room.getParticipantByIdentity(identity);
    if (participant is! RemoteParticipant) return;
    final enabled = !_remoteMuted && !_mutedRemoteIdentities.contains(identity);
    for (final publication in participant.audioTrackPublications) {
      final track = publication.track;
      if (track == null) continue;
      if (enabled) {
        await track.start();
      } else {
        await track.stop();
      }
    }
  }

  void _rememberIdentity({required String identity, required int uid}) {
    _uidByIdentity[identity] = uid;
    _identityByUid[uid] = identity;
  }

  int _participantUidForIdentity(String identity) {
    final remembered = _uidByIdentity[identity];
    if (remembered != null) return remembered;
    if (identity.toLowerCase() == "admin") {
      _rememberIdentity(identity: identity, uid: 900000001);
      return 900000001;
    }

    var hash = 0x811C9DC5;
    for (final code in "driver:$identity".codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    final uid = 100000 + (hash % 800000000);
    _rememberIdentity(identity: identity, uid: uid);
    return uid;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
