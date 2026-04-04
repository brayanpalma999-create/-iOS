import "dart:convert";
import "dart:io";

import "../models/support_ticket_model.dart";
import "../utils/constants.dart";

class SupportService {
  Future<List<SupportTicketModel>> fetchTickets({
    String? accountKey,
    String? role,
    String? status,
  }) async {
    final response = await _sendJsonRequest(
      method: "GET",
      path: AppConstants.supportTicketsPath,
      queryParameters: {
        if ((accountKey ?? "").trim().isNotEmpty) "accountKey": accountKey!.trim(),
        if ((role ?? "").trim().isNotEmpty) "role": role!.trim(),
        if ((status ?? "").trim().isNotEmpty) "status": status!.trim(),
        "limit": "200",
      },
    );
    if (response == null || response["ok"] != true) {
      return const <SupportTicketModel>[];
    }
    final raw = response["tickets"];
    if (raw is! List) return const <SupportTicketModel>[];
    return raw
        .whereType<Map>()
        .map((item) => SupportTicketModel.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<SupportTicketModel?> createTicket({
    required String accountKey,
    required String role,
    required String userName,
    required String userEmail,
    required String title,
    required String description,
    String category = "general",
    String priority = "normal",
  }) async {
    final response = await _sendJsonRequest(
      method: "POST",
      path: AppConstants.supportTicketsPath,
      body: {
        "accountKey": accountKey,
        "role": role,
        "userName": userName,
        "userEmail": userEmail,
        "title": title,
        "description": description,
        "category": category,
        "priority": priority,
      },
    );
    if (response == null || response["ok"] != true) return null;
    final ticket = response["ticket"];
    if (ticket is! Map) return null;
    return SupportTicketModel.fromJson(ticket.cast<String, dynamic>());
  }

  Future<SupportTicketModel?> updateTicket({
    required String ticketId,
    String? status,
    List<Map<String, dynamic>>? messages,
  }) async {
    final response = await _sendJsonRequest(
      method: "PATCH",
      path: "${AppConstants.supportTicketsPath}/$ticketId",
      body: {
        if ((status ?? "").trim().isNotEmpty) "status": status!.trim(),
        "messages": messages ?? const <Map<String, dynamic>>[],
      },
    );
    if (response == null || response["ok"] != true) return null;
    final ticket = response["ticket"];
    if (ticket is! Map) return null;
    return SupportTicketModel.fromJson(ticket.cast<String, dynamic>());
  }

  Future<Map<String, dynamic>?> _sendJsonRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final client = HttpClient();
    try {
      var uri = Uri.parse("${AppConstants.socketUrl}$path");
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, "application/json");
      if (body != null) {
        request.headers.set(
          HttpHeaders.contentTypeHeader,
          "application/json; charset=utf-8",
        );
        request.write(jsonEncode(body));
      }
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
