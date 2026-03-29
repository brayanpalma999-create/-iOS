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
}
