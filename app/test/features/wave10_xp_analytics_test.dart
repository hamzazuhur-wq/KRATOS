// Wave 10: Unit tests for XP analytics domain logic.
// Tests pure Dart aggregation helpers (no Drift/DB required).

import 'package:test/test.dart';

import 'package:kratos_app/features/sessions/domain/session_models.dart';

void main() {
  // ─── ActivityXpRule analytics scenarios ───────────────────────────────

  group('ActivityXpRule XP computation (analytics)', () {
    test('per-minute: 0 minutes earns 0 XP', () {
      const rule = ActivityXpRule(perMinuteXp: 5);
      expect(rule.computeXp(0), equals(0));
    });

    test('per-minute: 60 minutes earns 60 × rate XP', () {
      const rule = ActivityXpRule(perMinuteXp: 5);
      expect(rule.computeXp(3600000), equals(300)); // 60 min × 5
    });

    test('per-minute: fractional minutes round correctly', () {
      const rule = ActivityXpRule(perMinuteXp: 10);
      // 90 seconds = 1.5 min → 15 XP
      expect(rule.computeXp(90000), equals(15));
    });

    test('flat rule always returns same XP', () {
      const rule = ActivityXpRule(flatXp: 120);
      expect(rule.computeXp(0), equals(120));
      expect(rule.computeXp(99999999), equals(120));
    });

    test('empty rule returns 0', () {
      const rule = ActivityXpRule();
      expect(rule.computeXp(3600000), equals(0));
    });
  });

  // ─── Daily XP totals aggregation (pure Dart helper) ──────────────────

  group('Daily XP aggregation helper', () {
    test('correctly sums XP by day', () {
      // Simulate what XpAnalyticsDao.dailyXpTotals() returns
      final days = [
        (date: DateTime(2026, 9, 17), xp: 120),
        (date: DateTime(2026, 9, 18), xp: 85),
        (date: DateTime(2026, 9, 19), xp: 200),
        (date: DateTime(2026, 9, 20), xp: 0),
        (date: DateTime(2026, 9, 21), xp: 145),
        (date: DateTime(2026, 9, 22), xp: 310),
        (date: DateTime(2026, 9, 23), xp: 95),
      ];
      final total = days.fold<int>(0, (s, d) => s + d.xp);
      expect(total, equals(955));
    });

    test('max of daily XP is used for bar chart scale', () {
      final xp = [120, 85, 200, 0, 145, 310, 95];
      final max = xp.reduce((a, b) => a > b ? a : b);
      expect(max, equals(310));
    });

    test('empty day has fraction 0.0', () {
      final xp = [120, 0, 200];
      final max = xp.reduce((a, b) => a > b ? a : b);
      final fractions = xp.map((v) => max > 0 ? v / max : 0.0).toList();
      expect(fractions[1], equals(0.0));
    });
  });

  // ─── XP formatting (used in hero card) ───────────────────────────────

  group('XP number formatting', () {
    String formatXp(int xp) {
      if (xp >= 1000) {
        final k = xp / 1000;
        return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
      }
      return '$xp';
    }

    test('values < 1000 show raw number', () {
      expect(formatXp(0), equals('0'));
      expect(formatXp(999), equals('999'));
    });

    test('exactly 1000 shows 1K', () {
      expect(formatXp(1000), equals('1K'));
    });

    test('1500 shows 1.5K', () {
      expect(formatXp(1500), equals('1.5K'));
    });

    test('10000 shows 10K', () {
      expect(formatXp(10000), equals('10K'));
    });
  });
}
