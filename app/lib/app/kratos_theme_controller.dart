import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KRATOS App-Wide Theme Controller & Persistence Manager.
///
/// Follows strict project guidelines:
/// - Only Light and Dark modes (no System mode).
/// - Simple ChangeNotifier / ValueNotifier architecture without external state packages.
/// - Persisted using existing SharedPreferences under 'kratos.theme.mode'.
/// - Restored immediately on app launch.
class KratosThemeController extends ChangeNotifier {
  static const String preferenceKey = 'kratos.theme.mode';
  static final KratosThemeController instance = KratosThemeController._();

  KratosThemeController._();

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;

  /// Loads saved theme preference from local storage.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(preferenceKey);
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    } catch (_) {
      // Best-effort fallback to Dark
      _themeMode = ThemeMode.dark;
    }
  }

  /// Sets the theme mode and persists it immediately.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        preferenceKey,
        _themeMode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (_) {
      // Best-effort persistence
    }
  }

  /// Toggles between Light and Dark mode.
  Future<void> toggle() =>
      setThemeMode(_themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
