import "dart:io";

import "package:flutter/foundation.dart";
import "package:permission_handler/permission_handler.dart";

import "location_service.dart";

class PermissionService {
  const PermissionService._();

  static Future<void> requestStartupPermissions() async {
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    await LocationService().requestPermission();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _requestIfNeeded(Permission.microphone);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await _requestIfNeeded(Permission.notification);
  }

  static Future<void> _requestIfNeeded(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted ||
        status.isLimited ||
        status.isRestricted ||
        status.isPermanentlyDenied) {
      return;
    }
    await permission.request();
  }
}
