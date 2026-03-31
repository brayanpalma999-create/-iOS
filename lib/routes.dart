import "package:flutter/material.dart";

import "ui/screens/admin/admin_home.dart";
import "ui/screens/driver/driver_home.dart";
import "ui/screens/login_screen.dart";
import "ui/screens/splash_screen.dart";

class AppRoutes {
  static const splash = "/";
  static const login = "/login";
  static const adminHome = "/admin/home";
  static const driverHome = "/driver/home";

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen(), settings);
      case login:
        return _fade(const LoginScreen(), settings);
      case adminHome:
        return _fade(const AdminHome(), settings);
      case driverHome:
        return _fade(const DriverHome(), settings);
      default:
        return _fade(const LoginScreen(), settings);
    }
  }

  static PageRouteBuilder<dynamic> _fade(Widget child, RouteSettings settings) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      ),
    );
  }
}
