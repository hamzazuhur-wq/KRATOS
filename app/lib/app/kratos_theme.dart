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
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: electricLime,
      colorScheme: const ColorScheme.dark(
        primary: electricLime,
        secondary: classicAcidLime,
        surface: Color(0xFF0D100E),
      ),
      canvasColor: Colors.transparent,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: electricLime,
          side: const BorderSide(color: Color(0x4DEEFF08), width: 1.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: electricLime,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF0F1210),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1.0),
        ),
        titleTextStyle: const TextStyle(
          color: electricLime,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0F1210),
        modalBackgroundColor: Color(0xFF0F1210),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: Color(0x26FFFFFF), width: 1.0),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: volcanic,
        headerBackgroundColor: volcanicGreen,
        headerForegroundColor: Colors.white,
        dayForegroundColor: const WidgetStatePropertyAll(Colors.white),
        todayForegroundColor: const WidgetStatePropertyAll(acidLime),
        todayBackgroundColor: WidgetStatePropertyAll(acidLime.withValues(alpha: 0.1)),
        yearForegroundColor: const WidgetStatePropertyAll(Colors.white70),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white70),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: acidLime),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x26FFFFFF), width: 1.0),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: volcanic,
        hourMinuteTextColor: Colors.white,
        hourMinuteColor: volcanicGreen,
        dayPeriodTextColor: Colors.white,
        dayPeriodColor: volcanicGreen,
        dialHandColor: acidLime,
        dialBackgroundColor: volcanicGreen,
        dialTextColor: Colors.white,
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: Colors.white70),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: acidLime),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x26FFFFFF), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141715),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: electricLime, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.5),
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF141815),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x26FFFFFF), width: 1.0),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? electricLime : Colors.white60,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0x33EEFF08)
              : Colors.white12,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0x66EEFF08)
              : Colors.white24,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: const WidgetStatePropertyAll(deepBlack),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? electricLime : Colors.transparent,
        ),
        side: const BorderSide(color: Colors.white38, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? electricLime : Colors.white38,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 0.8,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x0FFFFFFF),
        selectedColor: const Color(0x2EEFFF08),
        disabledColor: const Color(0x08FFFFFF),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: electricLime, fontSize: 12, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0x1FFFFFFF), width: 0.8),
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xEE121512),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x26FFFFFF), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xF2121512),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x2EFFFFFF), width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: electricLime,
        linearTrackColor: Color(0x1AFFFFFF),
        circularTrackColor: Color(0x1AFFFFFF),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
        thickness: const WidgetStatePropertyAll(5.0),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? const Color(0x4DEEFF08)
              : const Color(0x26FFFFFF),
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
  static const Color lightBackground = Color(0xFFF7F6F2);
  static const Color lightSurface = Color(0xFFFAFAF7);
  static const Color lightSurfaceGlass = Color(0xF4F4F3EF);
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
      scaffoldBackgroundColor: Colors.transparent,
      primaryColor: lightAcidLime,
      colorScheme: const ColorScheme.light(
        primary: lightAcidLime,
        secondary: Color(0xFF4D7C0F),
        surface: lightSurface,
      ),
      canvasColor: Colors.transparent,
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightAcidLime,
          side: const BorderSide(color: lightAcidLime, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightAcidLime,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorderGlass, width: 1.0),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: lightBorderGlass, width: 1.0),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: const Color(0xFFF7F6F2),
        headerForegroundColor: lightTextPrimary,
        dayForegroundColor: const WidgetStatePropertyAll(lightTextPrimary),
        todayForegroundColor: const WidgetStatePropertyAll(lightAcidLime),
        todayBackgroundColor: WidgetStatePropertyAll(lightAcidLime.withValues(alpha: 0.1)),
        yearForegroundColor: const WidgetStatePropertyAll(lightTextSecondary),
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: lightTextSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: lightAcidLime),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorderGlass, width: 1.0),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        hourMinuteTextColor: lightTextPrimary,
        hourMinuteColor: const Color(0xFFF7F6F2),
        dayPeriodTextColor: lightTextPrimary,
        dayPeriodColor: const Color(0xFFF7F6F2),
        dialHandColor: lightAcidLime,
        dialBackgroundColor: const Color(0xFFF7F6F2),
        dialTextColor: lightTextPrimary,
        cancelButtonStyle: TextButton.styleFrom(foregroundColor: lightTextSecondary),
        confirmButtonStyle: TextButton.styleFrom(foregroundColor: lightAcidLime),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorderGlass, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x290F172A), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x290F172A), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightAcidLime, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorderGlass, width: 1.0),
        ),
        textStyle: const TextStyle(color: lightTextPrimary, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : lightTextSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? lightAcidLime : const Color(0x1F0F172A),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: const WidgetStatePropertyAll(Colors.white),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? lightAcidLime : Colors.transparent,
        ),
        side: const BorderSide(color: Color(0x4D0F172A), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? lightAcidLime : const Color(0x4D0F172A),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1F0F172A),
        thickness: 0.8,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x0A0F172A),
        selectedColor: const Color(0x24658F00),
        disabledColor: const Color(0x050F172A),
        labelStyle: const TextStyle(color: lightTextPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: lightAcidLime, fontSize: 12, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0x1F0F172A), width: 0.8),
        ),
        elevation: 0,
        pressElevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1F0F172A), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0x140F172A),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: const TextStyle(color: lightTextPrimary, fontSize: 11, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(color: lightTextPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x290F172A), width: 1.0),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: lightAcidLime,
        linearTrackColor: Color(0x1A0F172A),
        circularTrackColor: Color(0x1A0F172A),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(false),
        trackVisibility: const WidgetStatePropertyAll(false),
        thickness: const WidgetStatePropertyAll(5.0),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? const Color(0x4D658F00)
              : const Color(0x260F172A),
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
