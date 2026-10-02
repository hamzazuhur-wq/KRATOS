// ignore_for_file: public_member_api_docs
// Wave 18: KRATOS Liquid Glass & Dark Volcanic Theme.
// Design Tokens: Dark Volcanic #0D0D0D, Acid Lime #C6F135, Cyan #00BCD4, Glass surfaces.

import 'package:flutter/material.dart';

class KratosGlobalPageTransitionsBuilder extends PageTransitionsBuilder {
  const KratosGlobalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}

class KratosTheme {
  static const Color volcanic = Color(0xFF121212);
  static const Color volcanicRed = Color(0xFF260B06);
  static const Color olive = Color(0xFF4C561D);
  static const Color surfaceGlass = Color(0xFF1E1E1E);
  static const Color glassFill = Color(0xFF1E1E1E);
  static const Color borderGlass = Color(0x1FFFFFFF);
  static const Color acidLime = Color(0xFFC6F135);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color flameOrange = Color(0xFFFF9500);
  static const Color frostBlue = Color(0xFF00FFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      primaryColor: Colors.blueGrey,
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueGrey,
        secondary: Colors.teal,
        surface: Color(0xFF1E1E1E),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.iOS: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.linux: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.macOS: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.windows: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.fuchsia: KratosGlobalPageTransitionsBuilder(),
        },
      ),
    );
  }

  // Light Mode Tokens (standard neutral baseline compatibility)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xFFFFFFFF);
  static const Color lightBorderGlass = Color(0x1F000000);
  static const Color lightTextPrimary = Color(0xFF1F2937);
  static const Color lightTextSecondary = Color(0xFF4B5563);
  static const Color lightTextMuted = Color(0xFF9CA3AF);
  static const Color lightAcidLime = Color(0xFF4D7C0F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      primaryColor: Colors.blueGrey,
      colorScheme: const ColorScheme.light(
        primary: Colors.blueGrey,
        secondary: Colors.teal,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x1F000000)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.iOS: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.linux: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.macOS: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.windows: KratosGlobalPageTransitionsBuilder(),
          TargetPlatform.fuchsia: KratosGlobalPageTransitionsBuilder(),
        },
      ),
    );
  }
}
