// ignore_for_file: public_member_api_docs
// Wave 18: KRATOS Liquid Glass & Dark Volcanic Theme.
// Design Tokens: Dark Volcanic #0D0D0D, Acid Lime #C6F135, Cyan #00BCD4, Glass surfaces.

import 'dart:ui' as ui;

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

    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
    );

    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) {
        final progress = curved.value;
        final blur = 4.0 * (1.0 - progress);
        Widget revealed = Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 18.0 * (1.0 - progress)),
            child: Transform.scale(
              scale: 0.988 + (0.012 * progress),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
        if (blur > 0.05) {
          revealed = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: revealed,
          );
        }
        return revealed;
      },
    );
  }
}

class KratosTheme {
  static const Color volcanic = Color(0xFF0D0D0D);
  static const Color volcanicRed = Color(0xFF260B06);
  static const Color olive = Color(0xFF4C561D);
  static const Color surfaceGlass = Color(0x0DFFFFFF); // 5% white
  static const Color glassFill = Color(0x12FFFFFF); // translucent by design
  static const Color borderGlass = Color(0x1AFFFFFF); // 10% white
  static const Color acidLime = Color(0xFFC6F135);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color flameOrange = Color(0xFFFF9500);
  static const Color frostBlue = Color(0xFF00FFFF);

  static ThemeData get darkTheme {
    final liquidOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return acidLime.withValues(alpha: 0.20);
      }
      if (states.contains(WidgetState.hovered)) {
        return acidLime.withValues(alpha: 0.10);
      }
      if (states.contains(WidgetState.focused)) {
        return acidLime.withValues(alpha: 0.08);
      }
      return null;
    });
    final liquidElevation = WidgetStateProperty.resolveWith<double?>((states) {
      if (states.contains(WidgetState.pressed)) return 1;
      if (states.contains(WidgetState.hovered)) return 7;
      return 3;
    });

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: volcanic,
      primaryColor: acidLime,
      colorScheme: const ColorScheme.dark(
        primary: acidLime,
        secondary: cyan,
        surface: volcanic,
      ),
      splashFactory: InkRipple.splashFactory,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
          shadowColor: WidgetStatePropertyAll(acidLime.withValues(alpha: 0.18)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
          shadowColor: WidgetStatePropertyAll(acidLime.withValues(alpha: 0.18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        hoverColor: acidLime.withValues(alpha: 0.92),
        splashColor: acidLime.withValues(alpha: 0.24),
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        highlightElevation: 1,
      ),
      fontFamily: 'Roboto',
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: acidLime),
        titleTextStyle: TextStyle(
          color: acidLime,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGlass),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xE8080A08),
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.0,
          ),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Light Mode Tokens (Pure Liquid Glass, Ceramic Off-White, preserved KRATOS Acid Lime)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceGlass = Color(0xB8FFFFFF); // 72% frosted white
  static const Color lightBorderGlass = Color(0x1F000000); // 12% subtle dark border
  static const Color lightTextPrimary = Color(0xFF0F1115);
  static const Color lightTextSecondary = Color(0xFF5A606A);
  static const Color lightTextMuted = Color(0xFF8A92A0);
  /// Accessible KRATOS lime for light backgrounds with optimal contrast
  static const Color lightAcidLime = Color(0xFF6B9900);

  static ThemeData get lightTheme {
    final liquidOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return acidLime.withValues(alpha: 0.25);
      }
      if (states.contains(WidgetState.hovered)) {
        return acidLime.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused)) {
        return acidLime.withValues(alpha: 0.10);
      }
      return null;
    });
    final liquidElevation = WidgetStateProperty.resolveWith<double?>((states) {
      if (states.contains(WidgetState.pressed)) return 1;
      if (states.contains(WidgetState.hovered)) return 6;
      return 2;
    });

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: acidLime,
      colorScheme: const ColorScheme.light(
        primary: lightAcidLime,
        secondary: cyan,
        surface: lightSurface,
      ),
      splashFactory: InkRipple.splashFactory,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
          shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
          shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
          elevation: liquidElevation,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: const Duration(milliseconds: 180),
          overlayColor: liquidOverlay,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: acidLime,
        foregroundColor: volcanic,
        hoverColor: acidLime.withValues(alpha: 0.92),
        splashColor: acidLime.withValues(alpha: 0.24),
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        highlightElevation: 1,
      ),
      fontFamily: 'Roboto',
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
          fontSize: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorderGlass),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: lightSurface,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: lightBorderGlass,
            width: 1.0,
          ),
        ),
        textStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
