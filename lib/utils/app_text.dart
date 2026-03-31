import "package:flutter/widgets.dart";
import "package:provider/provider.dart";

import "../providers/auth_provider.dart";

extension AtoBAppText on BuildContext {
  String txt({required String es, required String en}) {
    final languageCode = select<AuthProvider, String>(
      (auth) => auth.languageCode,
    );
    return languageCode == "en" ? en : es;
  }

  bool get isEnglish =>
      select<AuthProvider, String>((auth) => auth.languageCode) == "en";

  String tripStatus(String raw) {
    switch (raw) {
      case "on_way":
        return txt(es: "En ruta", en: "On the way");
      case "assigned":
        return txt(es: "Asignado", en: "Assigned");
      case "accepted":
        return txt(es: "En ruta", en: "On the way");
      case "completed":
        return txt(es: "Completado", en: "Completed");
      case "rejected":
        return txt(es: "Rechazado", en: "Rejected");
      default:
        return raw;
    }
  }
}
