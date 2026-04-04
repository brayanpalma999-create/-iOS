import "package:flutter/foundation.dart";

import "../models/support_ticket_model.dart";
import "../services/support_service.dart";
import "../services/telemetry_service.dart";

class SupportProvider extends ChangeNotifier {
  SupportProvider({required SupportService supportService})
    : _supportService = supportService;

  final SupportService _supportService;

  List<SupportTicketModel> _tickets = const <SupportTicketModel>[];
  bool _loading = false;
  String? _error;

  List<SupportTicketModel> get tickets => List.unmodifiable(_tickets);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refresh({
    required String accountKey,
    required String role,
    bool silent = false,
  }) async {
    if (_loading) return;
    if (!silent) {
      _loading = true;
      notifyListeners();
    }
    try {
      _tickets = await _supportService.fetchTickets(
        accountKey: role == "admin" ? null : accountKey,
        role: role == "admin" ? null : role,
      );
      _error = null;
    } catch (error, stackTrace) {
      _error = error.toString();
      await TelemetryService.captureError(
        error,
        stackTrace: stackTrace,
        category: "support_refresh",
        context: {
          "accountKey": accountKey,
          "role": role,
        },
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
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
    final ticket = await _supportService.createTicket(
      accountKey: accountKey,
      role: role,
      userName: userName,
      userEmail: userEmail,
      title: title,
      description: description,
      category: category,
      priority: priority,
    );
    if (ticket != null) {
      _upsert(ticket);
      notifyListeners();
      await TelemetryService.captureMessage(
        "Support ticket created",
        category: "support_create",
        accountKey: accountKey,
        role: role,
        context: {
          "ticketId": ticket.id,
          "category": category,
          "priority": priority,
        },
      );
    }
    return ticket;
  }

  Future<SupportTicketModel?> updateTicketStatus({
    required String ticketId,
    required String status,
    String? authorRole,
    String? authorName,
    String? note,
  }) async {
    final messages = (note ?? "").trim().isEmpty
        ? null
        : <Map<String, dynamic>>[
            {
              "authorRole": (authorRole ?? "admin").trim(),
              "authorName": (authorName ?? "AtoB").trim(),
              "message": note!.trim(),
            },
          ];
    final ticket = await _supportService.updateTicket(
      ticketId: ticketId,
      status: status,
      messages: messages,
    );
    if (ticket != null) {
      _upsert(ticket);
      notifyListeners();
    }
    return ticket;
  }

  void _upsert(SupportTicketModel ticket) {
    final next = _tickets.toList(growable: true);
    final index = next.indexWhere((item) => item.id == ticket.id);
    if (index >= 0) {
      next[index] = ticket;
    } else {
      next.insert(0, ticket);
    }
    next.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _tickets = next;
  }
}
