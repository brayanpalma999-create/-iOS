class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.targetId,
    required this.createdAt,
    this.text = "",
    this.imageBase64,
    this.imageMimeType,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String targetId;
  final DateTime createdAt;
  final String text;
  final String? imageBase64;
  final String? imageMimeType;

  bool get hasImage =>
      imageBase64 != null && imageBase64!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    "id": id,
    "conversationId": conversationId,
    "senderId": senderId,
    "senderName": senderName,
    "senderRole": senderRole,
    "targetId": targetId,
    "createdAt": createdAt.toIso8601String(),
    "text": text,
    "imageBase64": imageBase64,
    "imageMimeType": imageMimeType,
  };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json["id"]?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: json["conversationId"]?.toString() ?? "",
      senderId: json["senderId"]?.toString() ?? "",
      senderName: json["senderName"]?.toString() ?? "Usuario",
      senderRole: json["senderRole"]?.toString() ?? "driver",
      targetId: json["targetId"]?.toString() ?? "",
      createdAt:
          DateTime.tryParse(json["createdAt"]?.toString() ?? "") ??
          DateTime.now(),
      text: json["text"]?.toString() ?? "",
      imageBase64: json["imageBase64"]?.toString(),
      imageMimeType: json["imageMimeType"]?.toString(),
    );
  }
}
