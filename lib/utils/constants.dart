import "package:flutter/material.dart";

class AppConstants {
  const AppConstants._();

  static const socketUrl = String.fromEnvironment(
    "SOCKET_URL",
    defaultValue: "https://atob-server.onrender.com",
  );
  static const socketPath = String.fromEnvironment(
    "SOCKET_PATH",
    defaultValue: "/socket.io",
  );
  static const mapboxToken = String.fromEnvironment(
    "MAPBOX_TOKEN",
    defaultValue: "",
  );
  static const tileModernUrl =
      "https://api.mapbox.com/styles/v1/mapbox/navigation-day-v1/tiles/256/{z}/{x}/{y}?access_token=$mapboxToken";
  static const tileNightUrl =
      "https://api.mapbox.com/styles/v1/mapbox/navigation-night-v1/tiles/256/{z}/{x}/{y}?access_token=$mapboxToken";
  static const tileSatelliteUrl =
      "https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}?access_token=$mapboxToken";
  static const tileFallbackUrl =
      "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
  static const appName = "AtoB";
  static const farePerMile = 2.25;
  static const minimumTripFare = 8.0;
  static const minimumFareMiles = 3.0;

  static const background = Color(0xFF050505);
  static const panel = Color(0xFF141414);
  static const panelSoft = Color(0xFF1B1B1B);
  static const stroke = Color(0xFFFFFFFF);
  static const accent = Color(0xFF3DDC97);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFF9FA3A8);

  static const pttOnAsset = "assets/sounds/ptt_on.wav";
  static const pttOffAsset = "assets/sounds/ptt_off.wav";
  static const privateBeepAsset = "assets/sounds/private_beep.wav";
  static const busyBeepAsset = "assets/sounds/busy_beep.wav";

  static const locationTick = Duration(seconds: 3);
}
