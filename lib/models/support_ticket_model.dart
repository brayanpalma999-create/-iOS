class SupportTicketMessageModel {
  const SupportTicketMessageModel({
    required this.id,
    required this.authorRole,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String authorRole;
  final String authorName;
  final String message;
  final DateTime createdAt;

  factory SupportTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessageModel(
      id: json["id"]?.toString() ?? "",
      authorRole: json["authorRole"]?.toString() ?? "driver",
      authorName: json["authorName"]?.toString() ?? "AtoB",
      message: json["message"]?.toString() ?? "",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "authorRole": authorRole,
    "authorName": authorName,
    "message": message,
    "createdAt": createdAt.toIso8601String(),
  };
}

class SupportTicketModel {
  const SupportTicketModel({
    required this.id,
    required this.accountKey,
    required this.role,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
    required this.userEmail,
    required this.messages,
  });

  final String id;
  final String accountKey;
  final String role;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userName;
  final String userEmail;
  final List<SupportTicketMessageModel> messages;

  bool get isOpen => status == "open" || status == "investigating";

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final rawMessages = json["messages"];
    return SupportTicketModel(
      id: json["id"]?.toString() ?? "",
      accountKey: json["accountKey"]?.toString() ?? "",
      role: json["role"]?.toString() ?? "driver",
      title: json["title"]?.toString() ?? "",
      description: json["description"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "general",
      priority: json["priority"]?.toString() ?? "normal",
      status: json["status"]?.toString() ?? "open",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json["updatedAt"]?.toString() ?? "") ??
          DateTime.now(),
      userName: json["userName"]?.toString() ?? "",
      userEmail: json["userEmail"]?.toString() ?? "",
      messages: rawMessages is! List
          ? const <SupportTicketMessageModel>[]
          : rawMessages
                .whereType<Map>()
                .map(
                  (item) => SupportTicketMessageModel.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false),
    );
  }
}
