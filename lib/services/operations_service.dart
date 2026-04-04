import "dart:convert";
import "dart:io";

import "../models/operations_model.dart";
import "../utils/constants.dart";

class OperationsService {
  Future<OperationsSummaryModel?> fetchSummary() async {
    final response = await _sendJsonRequest(
      method: "GET",
      path: "/operations/summary",
    );
    if (response == null || response["ok"] != true) return null;
    return OperationsSummaryModel.fromJson(response);
  }

  Future<Map<String, dynamic>?> _sendJsonRequest({
    required String method,
    required String path,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse("${AppConstants.socketUrl}$path");
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, "application/json");
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
