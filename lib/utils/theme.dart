import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "constants.dart";

ThemeData get appTheme {
  final text = GoogleFonts.plusJakartaSansTextTheme().apply(
    bodyColor: AppConstants.text,
    displayColor: AppConstants.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppConstants.background,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      bodyLarge: text.bodyLarge?.copyWith(
        height: 1.25,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.25),
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppConstants.stroke,
      secondary: AppConstants.accent,
      surface: AppConstants.panel,
      onPrimary: Colors.black,
      onSurface: AppConstants.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppConstants.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppConstants.text,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: const Color(0xCC0E0E0E),
      indicatorColor: const Color(0xFFF4F4F4),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? Colors.black : const Color(0xFF9E9E9E),
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? Colors.black : const Color(0xFFB0B0B0),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12.5,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: AppConstants.panelSoft,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x2CFFFFFF)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x30FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x30FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white, width: 1.2),
      ),
      hintStyle: const TextStyle(color: AppConstants.muted),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.resolveWith(
          (_) => const BorderSide(color: Color(0x3DFFFFFF)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFFFFFFF);
          }
          return const Color(0xFF151515);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.black;
          return Colors.white;
        }),
      ),
    ),
  );
}
