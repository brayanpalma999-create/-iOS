import "package:flutter/widgets.dart";
import "package:provider/provider.dart";

import "../providers/auth_provider.dart";

extension AtoBAppText on BuildContext {
  String txt({required String es, required String en}) {
    final languageCode = watch<AuthProvider>().languageCode;
    return languageCode == "en" ? en : es;
  }

  bool get isEnglish => watch<AuthProvider>().languageCode == "en";

  String tripStatus(String raw) {
    switch (raw) {
      case "on_way":
        return txt(es: "En ruta", en: "On the way");
      case "assigned":
        return txt(es: "Asignado", en: "Assigned");
      case "accepted":
        return txt(es: "En ruta", en: "On the way");
      case "picked_up":
        return txt(es: "Cliente a bordo", en: "Passenger onboard");
      case "completed":
        return txt(es: "Completado", en: "Completed");
      case "rejected":
        return txt(es: "Rechazado", en: "Rejected");
      case "cancelled":
        return txt(es: "Cancelado", en: "Cancelled");
      default:
        return raw;
    }
  }

  /// Bilingual alias — replaces the Spanish-only statusLabel from helpers.dart.
  String statusLabel(String raw) => tripStatus(raw);
}
