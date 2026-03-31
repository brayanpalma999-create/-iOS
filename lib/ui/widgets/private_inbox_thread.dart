import "dart:convert";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "../../models/chat_message_model.dart";
import "../../providers/chat_provider.dart";
import "../../utils/app_text.dart";

class PrivateInboxThread extends StatefulWidget {
  const PrivateInboxThread({
    super.key,
    required this.driverId,
    required this.peerLabel,
    this.emptyLabel = "No hay mensajes todavia",
  });

  final String driverId;
  final String peerLabel;
  final String emptyLabel;

  @override
  State<PrivateInboxThread> createState() => _PrivateInboxThreadState();
}

class _PrivateInboxThreadState extends State<PrivateInboxThread> {
  final TextEditingController _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<ChatProvider>().sendText(
        driverId: widget.driverId,
        text: text,
      );
      _messageCtrl.clear();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendPhoto() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await context.read<ChatProvider>().sendPhoto(driverId: widget.driverId);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String t({required String es, required String en}) =>
        context.txt(es: es, en: en);
    final chat = context.watch<ChatProvider>();
    final messages = chat.messagesForConversation(widget.driverId);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101214),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.forum_rounded, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peerLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      messages.isEmpty
                          ? widget.emptyLabel
                          : t(
                              es: "${messages.length} mensajes en esta conversacion",
                              en: "${messages.length} messages in this conversation",
                            ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _sendPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                tooltip: t(es: "Enviar foto", en: "Send photo"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 340,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF101214),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyLabel,
                    style: const TextStyle(color: Colors.white60),
                  ),
                )
              : ListView.separated(
                  reverse: true,
                  itemCount: messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = messages[messages.length - 1 - index];
                    return _MessageBubble(
                      message: item,
                      mine: chat.isMine(item),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageCtrl,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t(es: "Escribe un mensaje", en: "Write a message"),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _sending ? null : _sendText,
              child: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        if (chat.lastError != null) ...[
          const SizedBox(height: 8),
          Text(
            chat.lastError!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        ],
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessageModel message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine
        ? const Color(0xFF19352C)
        : const Color(0xFF17191B);
    final borderColor = mine
        ? const Color(0x553DDC97)
        : const Color(0x22FFFFFF);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? context.txt(es: "Tu", en: "You") : message.senderName,
                style: TextStyle(
                  color: mine ? const Color(0xFF8DF5C6) : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              if (message.text.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(message.text),
              ],
              if (message.hasImage) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(message.imageBase64!),
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                _clockLabel(message.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _clockLabel(DateTime value) {
    final hh = value.hour.toString().padLeft(2, "0");
    final mm = value.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }
}
