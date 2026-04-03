import "package:flutter/material.dart";

enum MapThemeMode { flow, dark, satellite }

class MapUiProvider extends ChangeNotifier {
  MapThemeMode _themeMode = MapThemeMode.flow;

  MapThemeMode get themeMode => _themeMode;

  void setThemeMode(MapThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setThemeModeFromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case "dark":
        setThemeMode(MapThemeMode.dark);
        return;
      case "satellite":
        setThemeMode(MapThemeMode.satellite);
        return;
      default:
        setThemeMode(MapThemeMode.flow);
    }
  }

  String get modeName => switch (_themeMode) {
    MapThemeMode.flow => "flow",
    MapThemeMode.dark => "dark",
    MapThemeMode.satellite => "satellite",
  };
}
