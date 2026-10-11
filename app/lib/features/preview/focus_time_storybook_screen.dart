import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/data/analytics_mock_data.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/focus_time/analytics_focus_time_section.dart';

/// Interactive Storybook preview for KRATOS Focus Time.
///
/// Supports:
/// - Light & Dark theme toggle
/// - Populated vs Empty state toggle
/// - Responsive breakpoint preview
class FocusTimeStorybookScreen extends StatefulWidget {
  const FocusTimeStorybookScreen({super.key});

  @override
  State<FocusTimeStorybookScreen> createState() =>
      _FocusTimeStorybookScreenState();
}

class _FocusTimeStorybookScreenState extends State<FocusTimeStorybookScreen> {
  late bool _isDark;
  bool _isEmpty = false;
  final AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.sevenDays;

  @override
  void initState() {
    super.initState();
    final themeParam = Uri.base.queryParameters['theme'];
    if (themeParam == 'light') {
      _isDark = false;
      KratosThemeController.instance.setThemeMode(ThemeMode.light);
    } else if (themeParam == 'dark') {
      _isDark = true;
      KratosThemeController.instance.setThemeMode(ThemeMode.dark);
    } else {
      _isDark = KratosThemeController.instance.isDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = _isDark ? KratosTheme.darkTheme : KratosTheme.lightTheme;
    final range = AnalyticsDateRange.forPeriod(_selectedPeriod);

    final FocusTimeSnapshot snapshot;
    if (_isEmpty) {
      snapshot = FocusTimeSnapshot.empty(range);
    } else {
      final mockSnapshot = AnalyticsMockData.snapshot(range: range);
      snapshot = mockSnapshot.safeFocusTime;
    }

    final bg = _isDark
        ? const Color(0xFF0D0F12)
        : const Color(0xFFF6F7F9);

    return Theme(
      data: themeData,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: _isDark ? const Color(0xFF13161A) : Colors.white,
          elevation: 0,
          title: Text(
            'Focus Time Storybook',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _isDark ? Colors.white : KratosTheme.lightTextPrimary,
            ),
          ),
          actions: [
            // Populated / Empty Toggle
            IconButton(
              icon: Icon(
                _isEmpty ? Icons.data_usage_rounded : Icons.clear_all_rounded,
                color: _isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
              ),
              tooltip: _isEmpty ? 'Switch to Populated Data' : 'Switch to Empty State',
              onPressed: () => setState(() => _isEmpty = !_isEmpty),
            ),
            // Light / Dark Theme Toggle
            IconButton(
              icon: Icon(
                _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: _isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
              ),
              tooltip: _isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
              onPressed: () {
                final next = !_isDark;
                setState(() => _isDark = next);
                KratosThemeController.instance.setThemeMode(
                  next ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: AnalyticsFocusTimeSection(
                snapshot: snapshot,
                periodLabel: _selectedPeriod.label,
                periodSubtitle: _selectedPeriod.comparisonLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
