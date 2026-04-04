import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:provider/provider.dart";

import "providers/admin_provider.dart";
import "providers/auth_provider.dart";
import "providers/chat_provider.dart";
import "providers/driver_provider.dart";
import "providers/intercom_provider.dart";
import "providers/map_ui_provider.dart";
import "providers/operations_provider.dart";
import "providers/trip_provider.dart";
import "routes.dart";
import "services/beep_service.dart";
import "services/livekit_intercom_service.dart";
import "services/livekit_token_service.dart";
import "services/location_service.dart";
import "services/map_service.dart";
import "services/operations_service.dart";
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
        Provider<MapService>(create: (_) => MapService()),
        Provider<OperationsService>(create: (_) => OperationsService()),
        Provider<BeepService>(create: (_) => BeepService()),
        Provider<LiveKitTokenService>(
          create: (_) => LiveKitTokenService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<LiveKitIntercomService>(
          create: (context) => LiveKitIntercomService(
            tokenService: context.read<LiveKitTokenService>(),
          ),
        ),
        Provider<TripService>(create: (_) => TripService()),
        ChangeNotifierProvider<MapUiProvider>(create: (_) => MapUiProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<OperationsProvider>(
          create: (context) => OperationsProvider(
            operationsService: context.read<OperationsService>(),
          ),
        ),
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
        ChangeNotifierProxyProvider4<
          SocketService,
          LocationService,
          MapService,
          TripProvider,
          DriverProvider
        >(
          create: (context) => DriverProvider(
            socketService: context.read<SocketService>(),
            locationService: context.read<LocationService>(),
            mapService: context.read<MapService>(),
            tripProvider: context.read<TripProvider>(),
          ),
          update:
              (
                context,
                socketService,
                locationService,
                mapService,
                tripProvider,
                previous,
              ) =>
                  previous ??
                  DriverProvider(
                    socketService: socketService,
                    locationService: locationService,
                    mapService: mapService,
                    tripProvider: tripProvider,
                  ),
        ),
        ChangeNotifierProxyProvider2<
          SocketService,
          DriverProvider,
          ChatProvider
        >(
          create: (context) => ChatProvider(
            socketService: context.read<SocketService>(),
            driverProvider: context.read<DriverProvider>(),
          ),
          update: (context, socketService, driverProvider, previous) =>
              previous ??
              ChatProvider(
                socketService: socketService,
                driverProvider: driverProvider,
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
          DriverProvider,
          BeepService,
          LiveKitIntercomService,
          IntercomProvider
        >(
          create: (context) => IntercomProvider(
            driverProvider: context.read<DriverProvider>(),
            beepService: context.read<BeepService>(),
            liveKitService: context.read<LiveKitIntercomService>(),
          ),
          update:
              (
                context,
                driverProvider,
                beepService,
                liveKitService,
                previous,
              ) =>
                  previous ??
                  IntercomProvider(
                    driverProvider: driverProvider,
                    beepService: beepService,
                    liveKitService: liveKitService,
                  ),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) => MaterialApp(
          title: "AtoB",
          debugShowCheckedModeBanner: false,
          theme: appTheme,
          locale: Locale(auth.languageCode),
          supportedLocales: const [Locale("es"), Locale("en")],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
