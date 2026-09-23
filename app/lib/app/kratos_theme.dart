// ignore_for_file: public_member_api_docs
// Wave 18: KRATOS Liquid Glass & Dark Volcanic Theme.
// Design Tokens: Dark Volcanic #0D0D0D, Acid Lime #C6F135, Cyan #00BCD4, Glass surfaces.

import 'package:flutter/material.dart';

class KratosTheme {
  static const Color volcanic = Color(0xFF0D0D0D);
  static const Color surfaceGlass = Color(0x0DFFFFFF); // 5% white
  static const Color borderGlass = Color(0x1AFFFFFF); // 10% white
  static const Color acidLime = Color(0xFFC6F135);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color flameOrange = Color(0xFFFF9500);
  static const Color frostBlue = Color(0xFF00FFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: volcanic,
      primaryColor: acidLime,
      colorScheme: const ColorScheme.dark(
        primary: acidLime,
        secondary: cyan,
        surface: volcanic,
      ),
      fontFamily: 'Roboto',
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
      cardTheme: CardTheme(
        color: surfaceGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderGlass),
        ),
      ),
    );
  }
}
