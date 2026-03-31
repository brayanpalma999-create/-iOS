import "dart:async";
import "dart:convert";
import "dart:io";

import "../utils/constants.dart";

class LiveKitJoinCredentials {
  const LiveKitJoinCredentials({
    required this.serverUrl,
    required this.token,
    required this.roomName,
  });

  final String serverUrl;
  final String token;
  final String roomName;
}

class LiveKitTokenService {
  LiveKitTokenService() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  final HttpClient _client = HttpClient();

  Future<LiveKitJoinCredentials> fetchJoinCredentials({
    required String roomName,
    required String identity,
    required String name,
    required String role,
  }) async {
    final uri = Uri.parse(AppConstants.liveKitTokenUrl).replace(
      queryParameters: <String, String>{
        "roomName": roomName,
        "identity": identity,
        "name": name,
        "role": role,
      },
    );

    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, "application/json");

    final response = await request.close().timeout(const Duration(seconds: 8));
    final raw = await utf8.decoder.bind(response).join();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    final body = decoded is Map
        ? decoded.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          body["message"]?.toString().trim() ??
          "LiveKit token server respondio ${response.statusCode}";
      throw StateError(message);
    }

    final serverUrl = body["serverUrl"]?.toString().trim() ?? "";
    final token = body["token"]?.toString().trim() ?? "";
    final resolvedRoomName =
        body["roomName"]?.toString().trim() ?? roomName.trim();
    if (serverUrl.isEmpty || token.isEmpty || resolvedRoomName.isEmpty) {
      throw StateError("Respuesta incompleta del token server LiveKit");
    }
    return LiveKitJoinCredentials(
      serverUrl: serverUrl,
      token: token,
      roomName: resolvedRoomName,
    );
  }

  void dispose() {
    _client.close(force: true);
  }
}
