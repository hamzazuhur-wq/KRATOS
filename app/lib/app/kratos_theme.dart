// ignore_for_file: public_member_api_docs
// KRATOS Original Approved Visual Foundation
// Palette: Deep Black #020302 / #050505, Primary Accent #EEFF08, Volcanic Undertone #260B06

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
  // Primary Palette Tokens (Approved Original Direction)
  static const Color deepBlack = Color(0xFF020302);
  static const Color deepBlackAlt = Color(0xFF050505);
  static const Color volcanic = Color(0xFF0D0F0D);
  static const Color volcanicRed = Color(0xFF260B06);
  static const Color volcanicGreen = Color(0xFF141814);

  // Primary KRATOS Accent (Electric Acid Lime)
  static const Color electricLime = Color(0xFFEEFF08);
  static const Color acidLime = Color(0xFFEEFF08);
  static const Color classicAcidLime = Color(0xFFC6F135);

  // Accent / Status Accents
  static const Color cyan = Color(0xFF00BCD4);
  static const Color flameOrange = Color(0xFFFF9500);
  static const Color frostBlue = Color(0xFF00FFFF);
  static const Color olive = Color(0xFF4C561D);

  // Glass & Surface Tokens
  static const Color surfaceGlass = Color(0x14FFFFFF);
  static const Color glassFill = Color(0x0DFFFFFF);
  static const Color borderGlass = Color(0x1AFFFFFF);

  // Dark Theme Hierarchy
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deepBlack,
      primaryColor: electricLime,
      colorScheme: const ColorScheme.dark(
        primary: electricLime,
        secondary: classicAcidLime,
        surface: Color(0xFF0D100E),
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white70),
        titleTextStyle: TextStyle(
          color: electricLime,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF101311),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: electricLime,
        foregroundColor: deepBlack,
        elevation: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: electricLime,
          foregroundColor: deepBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
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

  // Light Mode Tokens (Sophisticated Architectural Ceramic)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xF7FFFFFF);
  static const Color lightBorderGlass = Color(0x1F0F172A);
  static const Color lightTextPrimary = Color(0xFF0F1115);
  static const Color lightTextSecondary = Color(0xFF5A606A);
  static const Color lightTextMuted = Color(0xFF8A92A0);
  /// Accessible high-contrast KRATOS lime for light backgrounds
  static const Color lightAcidLime = Color(0xFF658F00);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightAcidLime,
      colorScheme: const ColorScheme.light(
        primary: lightAcidLime,
        secondary: Color(0xFF4D7C0F),
        surface: lightSurface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1F0F172A), width: 1.0),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightAcidLime,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightAcidLime,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
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
