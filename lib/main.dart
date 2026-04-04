import "package:flutter/widgets.dart";

import "app.dart";
import "services/telemetry_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TelemetryService.initialize();
  runApp(const AtoBApp());
}
