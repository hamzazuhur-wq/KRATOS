import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kratos_app/app/kratos_card_tokens.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/app/kratos_theme_controller.dart';
import 'package:kratos_app/app/kratos_visuals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KratosThemeController & Exact Design Integration', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await KratosThemeController.instance.setThemeMode(ThemeMode.dark);
    });

    test('persists and restores theme mode via SharedPreferences', () async {
      final controller = KratosThemeController.instance;

      // Initial state is dark
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.isDark, isTrue);
      expect(controller.isLight, isFalse);

      // Switch to light mode
      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, ThemeMode.light);
      expect(controller.isLight, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(KratosThemeController.preferenceKey), 'light');

      // Reload controller from prefs
      await controller.load();
      expect(controller.themeMode, ThemeMode.light);

      // Switch back to dark mode
      await controller.toggle();
      expect(controller.themeMode, ThemeMode.dark);
      expect(prefs.getString(KratosThemeController.preferenceKey), 'dark');
    });

    testWidgets('dynamic theme switch updates KratosEnvironment and KratosGlassCard seamlessly',
        (tester) async {
      final controller = KratosThemeController.instance;
      await controller.setThemeMode(ThemeMode.dark);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return MaterialApp(
              theme: KratosTheme.lightTheme,
              darkTheme: KratosTheme.darkTheme,
              themeMode: controller.themeMode,
              builder: (context, child) =>
                  KratosEnvironment(child: child ?? const SizedBox.shrink()),
              home: const Scaffold(
                body: Center(
                  child: KratosGlassCard(
                    child: Text('Dynamic Theme Card'),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      // In Dark mode:
      expect(find.text('Dynamic Theme Card'), findsOneWidget);
      var cardContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      var cardBox = cardContainer.decoration as BoxDecoration;
      var cardBorder = cardBox.border as Border;
      expect(cardBorder.top.color.a, closeTo(0.22, 0.02));

      // Switch to Light mode on the fly
      await controller.setThemeMode(ThemeMode.light);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // In Light mode:
      cardContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      cardBox = cardContainer.decoration as BoxDecoration;
      cardBorder = cardBox.border as Border;
      expect(cardBorder.top.color.a, closeTo(0.80, 0.02));

      // Switch back to Dark mode
      await controller.setThemeMode(ThemeMode.dark);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      cardContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      cardBox = cardContainer.decoration as BoxDecoration;
      cardBorder = cardBox.border as Border;
      expect(cardBorder.top.color.a, closeTo(0.22, 0.02));
    });

    test('exact reference token values match manus-visual-reference.html', () {
      final darkTokens = KratosCardTokens.dark();
      final lightTokens = KratosCardTokens.light();

      // Dark accent matches --lime: #eeff08
      expect(darkTokens.accentColor, const Color(0xFFEEFF08));
      expect(darkTokens.glowColor, const Color(0xFFEEFF08));
      // Dark blur matches backdrop-filter: blur(18px)
      expect(darkTokens.blurSigma, 18.0);
      // Dark active border matches rgba(238,255,8,.7)
      expect(darkTokens.borderActive.a, closeTo(0.70, 0.01));
      // Dark elevated border matches rgba(238,255,8,.26)
      expect(darkTokens.borderElevated.a, closeTo(0.26, 0.01));

      // Light accent matches --lime-deep: #a8b800
      expect(lightTokens.accentColor, const Color(0xFFA8B800));
      expect(lightTokens.glowColor, const Color(0xFFA8B800));
      // Light blur matches backdrop-filter: blur(18px)
      expect(lightTokens.blurSigma, 18.0);
      // Light active border matches rgba(168,184,0,.46)
      expect(lightTokens.borderActive.a, closeTo(0.46, 0.01));
    });
  });
}
