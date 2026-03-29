import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "providers/admin_provider.dart";
import "providers/auth_provider.dart";
import "providers/driver_provider.dart";
import "providers/intercom_provider.dart";
import "providers/map_ui_provider.dart";
import "providers/trip_provider.dart";
import "routes.dart";
import "services/audio_capture_service.dart";
import "services/beep_service.dart";
import "services/location_service.dart";
import "services/permission_service.dart";
import "services/socket_service.dart";
import "services/trip_service.dart";
import "utils/theme.dart";

class AtoBApp extends StatefulWidget {
  const AtoBApp({super.key});

  @override
  State<AtoBApp> createState() => _AtoBAppState();
}

class _AtoBAppState extends State<AtoBApp> with WidgetsBindingObserver {
  bool _requestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_requestPermissions());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_requestPermissions());
    }
  }

  Future<void> _requestPermissions() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    try {
      await PermissionService.requestStartupPermissions();
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SocketService>(create: (_) => SocketService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<BeepService>(create: (_) => BeepService()),
        Provider<AudioCaptureService>(create: (_) => AudioCaptureService()),
        Provider<TripService>(create: (_) => TripService()),
        ChangeNotifierProvider<MapUiProvider>(create: (_) => MapUiProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider2<SocketService, TripService, TripProvider>(
          create: (context) => TripProvider(
            socketService: context.read<SocketService>(),
            tripService: context.read<TripService>(),
          ),
          update: (context, socketService, tripService, previous) =>
              previous ??
              TripProvider(
                socketService: socketService,
                tripService: tripService,
              ),
        ),
        ChangeNotifierProxyProvider3<
          SocketService,
          LocationService,
          TripProvider,
          DriverProvider
        >(
          create: (context) => DriverProvider(
            socketService: context.read<SocketService>(),
            locationService: context.read<LocationService>(),
            tripProvider: context.read<TripProvider>(),
          ),
          update:
              (
                context,
                socketService,
                locationService,
                tripProvider,
                previous,
              ) =>
                  previous ??
                  DriverProvider(
                    socketService: socketService,
                    locationService: locationService,
                    tripProvider: tripProvider,
                  ),
        ),
        ChangeNotifierProxyProvider2<
          SocketService,
          DriverProvider,
          AdminProvider
        >(
          create: (context) => AdminProvider(
            socketService: context.read<SocketService>(),
            driverProvider: context.read<DriverProvider>(),
          ),
          update: (context, socketService, driverProvider, previous) =>
              previous ??
              AdminProvider(
                socketService: socketService,
                driverProvider: driverProvider,
              ),
        ),
        ChangeNotifierProxyProvider3<
          SocketService,
          BeepService,
          AudioCaptureService,
          IntercomProvider
        >(
          create: (context) => IntercomProvider(
            socketService: context.read<SocketService>(),
            beepService: context.read<BeepService>(),
            audioCaptureService: context.read<AudioCaptureService>(),
          ),
          update:
              (
                context,
                socketService,
                beepService,
                audioCaptureService,
                previous,
              ) =>
                  previous ??
                  IntercomProvider(
                    socketService: socketService,
                    beepService: beepService,
                    audioCaptureService: audioCaptureService,
                  ),
        ),
      ],
      child: MaterialApp(
        title: "AtoB",
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        initialRoute: AppRoutes.login,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
