String shortClock(DateTime dateTime) {
  final hh = dateTime.hour.toString().padLeft(2, "0");
  final mm = dateTime.minute.toString().padLeft(2, "0");
  final ss = dateTime.second.toString().padLeft(2, "0");
  return "$hh:$mm:$ss";
}

String statusLabel(String raw) {
  switch (raw) {
    case "on_way":
      return "En ruta";
    case "assigned":
      return "Asignado";
    case "accepted":
      return "En ruta";
    case "picked_up":
      return "Cliente a bordo";
    case "completed":
      return "Completado";
    case "rejected":
      return "Rechazado";
    default:
      return raw;
  }
}

String usd(double value) => "\$${value.toStringAsFixed(2)}";

String milesText(double miles) => "${miles.toStringAsFixed(2)} mi";

String percent(double value) => "${(value * 100).toStringAsFixed(0)}%";

String compactPersonName(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r"\s+"))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) return "Usuario";
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) {
    return "${parts.first} ${parts.last}";
  }
  final firstName = parts.first;
  final mainSurname = parts[parts.length - 2];
  return "$firstName $mainSurname";
}

String etaClock(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, "0");
  final suffix = dateTime.hour >= 12 ? "PM" : "AM";
  return "$hour:$minute $suffix";
}
