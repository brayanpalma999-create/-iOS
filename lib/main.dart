import "package:flutter/widgets.dart";

import "app.dart";
import "services/permission_service.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionService.requestStartupPermissions();
  runApp(const AtoBApp());
}
