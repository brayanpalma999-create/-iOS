import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "../utils/constants.dart";

class TelemetryService {
  const TelemetryService._();

  static Future<void> initialize() async {
    if (AppConstants.hasSentryDsn) {
      await SentryFlutter.init((options) {
        options.dsn = AppConstants.sentryDsn;
        options.tracesSampleRate = 0.15;
        options.sendDefaultPii = false;
      }, appRunner: () {});
    }
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        captureError(
          details.exception,
          stackTrace: details.stack,
          category: "flutter_error",
          context: {
            "library": details.library,
            "context": details.context?.toDescription(),
          },
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        captureError(
          error,
          stackTrace: stack,
          category: "platform_error",
        ),
      );
      return true;
    };
  }

  static Future<void> captureMessage(
    String message, {
    String level = "info",
    String category = "client",
    Map<String, dynamic>? context,
    String? accountKey,
    String? role,
  }) async {
    if (message.trim().isEmpty) return;
    if (AppConstants.hasSentryDsn) {
      await Sentry.captureMessage(
        message,
        level: _sentryLevel(level),
        withScope: (scope) {
          scope.setTag("category", category);
          if ((accountKey ?? "").trim().isNotEmpty) {
            scope.setTag("accountKey", accountKey!.trim());
          }
          if ((role ?? "").trim().isNotEmpty) {
            scope.setTag("role", role!.trim());
          }
          if (context != null && context.isNotEmpty) {
            scope.setContexts("telemetry_context", context);
          }
        },
      );
    }
    await _postEvent({
      "level": level,
      "category": category,
      "message": message,
      "accountKey": accountKey,
      "role": role,
      "platform": defaultTargetPlatform.name,
      "build": "flutter",
      "context": context ?? const <String, dynamic>{},
    });
  }

  static Future<void> captureError(
    Object error, {
    StackTrace? stackTrace,
    String category = "exception",
    Map<String, dynamic>? context,
    String? accountKey,
    String? role,
  }) async {
    if (AppConstants.hasSentryDsn) {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag("category", category);
          if ((accountKey ?? "").trim().isNotEmpty) {
            scope.setTag("accountKey", accountKey!.trim());
          }
          if ((role ?? "").trim().isNotEmpty) {
            scope.setTag("role", role!.trim());
          }
          if (context != null && context.isNotEmpty) {
            scope.setContexts("telemetry_context", context);
          }
        },
      );
    }
    await _postEvent({
      "level": "error",
      "category": category,
      "message": error.toString(),
      "accountKey": accountKey,
      "role": role,
      "platform": defaultTargetPlatform.name,
      "build": "flutter",
      "stack": stackTrace?.toString(),
      "context": context ?? const <String, dynamic>{},
    });
  }

  static Future<void> _postEvent(Map<String, dynamic> payload) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(AppConstants.telemetryEventsUrl));
      request.headers.set(HttpHeaders.acceptHeader, "application/json");
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        "application/json; charset=utf-8",
      );
      request.write(jsonEncode(payload));
      await request.close().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Ignore telemetry transport failures.
    } finally {
      client.close(force: true);
    }
  }

  static SentryLevel _sentryLevel(String level) {
    switch (level.trim().toLowerCase()) {
      case "debug":
        return SentryLevel.debug;
      case "warning":
        return SentryLevel.warning;
      case "error":
        return SentryLevel.error;
      case "fatal":
        return SentryLevel.fatal;
      default:
        return SentryLevel.info;
    }
  }
}
