import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/trip_model.dart";

class RouteNotificationAction {
  const RouteNotificationAction({
    required this.tripId,
    required this.actionId,
  });

  final String tripId;
  final String actionId;

  Map<String, dynamic> toJson() => {
    "tripId": tripId,
    "actionId": actionId,
  };

  factory RouteNotificationAction.fromJson(Map<String, dynamic> json) {
    return RouteNotificationAction(
      tripId: json["tripId"]?.toString() ?? "",
      actionId: json["actionId"]?.toString() ?? "",
    );
  }
}

@pragma("vm:entry-point")
Future<void> onDidReceiveRouteNotificationBackground(
  NotificationResponse response,
) async {
  final action = RouteNotificationService.parseAction(response);
  if (action == null) return;
  await RouteNotificationService.persistPendingAction(action);
}

class RouteNotificationService {
  RouteNotificationService();

  static const String tripChannelId = "atob_trip_assignments";
  static const String tripChannelName = "Trip assignments";
  static const String tripChannelDescription =
      "Trip assignment alerts with start-route action";
  static const String openTripActionId = "open_trip";
  static const String startRouteActionId = "start_route";
  static const String _pendingActionKey =
      "atob_pending_route_notification_action_v1";

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<RouteNotificationAction> _actions =
      StreamController<RouteNotificationAction>.broadcast();

  bool _initialized = false;

  Stream<RouteNotificationAction> get actions => _actions.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    const androidSettings = AndroidInitializationSettings("@mipmap/ic_launcher");
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: <DarwinNotificationCategory>[
        DarwinNotificationCategory(
          tripChannelId,
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(openTripActionId, "Abrir"),
            DarwinNotificationAction.plain(startRouteActionId, "Iniciar ruta"),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveRouteNotificationBackground,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        tripChannelId,
        tripChannelName,
        description: tripChannelDescription,
        importance: Importance.max,
      ),
    );

    final iosImplementation = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> dispose() async {
    await _actions.close();
  }

  Future<void> showTripAssignedNotification(TripModel trip) async {
    await initialize();
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    final payload = jsonEncode({
      "tripId": trip.id,
      "type": "trip_assigned",
    });

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        tripChannelId,
        tripChannelName,
        channelDescription: tripChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.transport,
        playSound: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(openTripActionId, "Abrir"),
          AndroidNotificationAction(startRouteActionId, "Iniciar ruta"),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: tripChannelId,
      ),
    );

    await _plugin.show(
      _notificationIdForTrip(trip.id),
      "Ruta asignada",
      "${trip.origin} -> ${trip.destination}",
      details,
      payload: payload,
    );
  }

  Future<RouteNotificationAction?> consumePendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingActionKey);
    if ((raw ?? "").trim().isEmpty) return null;
    await prefs.remove(_pendingActionKey);
    try {
      final decoded = jsonDecode(raw!);
      if (decoded is Map<String, dynamic>) {
        return RouteNotificationAction.fromJson(decoded);
      }
      if (decoded is Map) {
        return RouteNotificationAction.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      // Ignore malformed pending notification state.
    }
    return null;
  }

  static RouteNotificationAction? parseAction(NotificationResponse response) {
    final payloadText = response.payload?.trim();
    if ((payloadText ?? "").isEmpty) return null;
    try {
      final decoded = jsonDecode(payloadText!);
      if (decoded is! Map) return null;
      final tripId = decoded["tripId"]?.toString().trim() ?? "";
      if (tripId.isEmpty) return null;
      final actionId = (response.actionId ?? "").trim().isEmpty
          ? openTripActionId
          : response.actionId!.trim();
      return RouteNotificationAction(
        tripId: tripId,
        actionId: actionId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> persistPendingAction(RouteNotificationAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActionKey, jsonEncode(action.toJson()));
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final action = parseAction(response);
    if (action == null) return;
    unawaited(persistPendingAction(action));
    _actions.add(action);
  }

  int _notificationIdForTrip(String tripId) {
    return tripChannelId.hashCode ^ tripId.hashCode;
  }
}
