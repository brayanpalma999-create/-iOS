import "dart:io";

import "package:flutter/foundation.dart";
import "package:permission_handler/permission_handler.dart";

class PermissionService {
  const PermissionService._();

  static Future<void> requestStartupPermissions() async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    await _requestIfNeeded(Permission.locationWhenInUse);
    await _requestIfNeeded(Permission.microphone);
    await _requestIfNeeded(Permission.notification);
  }

  static Future<void> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return;
    await permission.request();
  }
}
