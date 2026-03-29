String shortClock(DateTime dateTime) {
  final hh = dateTime.hour.toString().padLeft(2, "0");
  final mm = dateTime.minute.toString().padLeft(2, "0");
  final ss = dateTime.second.toString().padLeft(2, "0");
  return "$hh:$mm:$ss";
}

String statusLabel(String raw) {
  switch (raw) {
    case "on_way":
      return "En camino";
    case "assigned":
      return "Asignado";
    case "accepted":
      return "En camino";
    case "rejected":
      return "Rechazado";
    default:
      return raw;
  }
}

String usd(double value) => "\$${value.toStringAsFixed(2)}";

String milesText(double miles) => "${miles.toStringAsFixed(2)} mi";

String percent(double value) => "${(value * 100).toStringAsFixed(0)}%";
