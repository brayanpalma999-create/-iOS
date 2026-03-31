import "dart:io";

import "package:flutter/material.dart";

ImageProvider<Object>? avatarFileProvider(String? avatarPath) {
  final normalized = (avatarPath ?? "").trim();
  if (normalized.isEmpty) return null;
  final file = File(normalized);
  if (!file.existsSync()) return null;
  return FileImage(file);
}

class EditableAvatarCard extends StatelessWidget {
  const EditableAvatarCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.name,
    required this.avatarPath,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final String name;
  final String? avatarPath;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final imageProvider = avatarFileProvider(avatarPath);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101214),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0x1F3DDC97),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8DF5C6),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Column(
            children: [
              TextButton(
                onPressed: busy ? null : onPick,
                child: Text(busy ? "Cargando..." : "Cambiar"),
              ),
              if (imageProvider != null)
                TextButton(
                  onPressed: busy ? null : onRemove,
                  child: const Text("Quitar"),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
