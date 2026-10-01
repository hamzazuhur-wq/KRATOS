import 'package:flutter/material.dart';

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_dropdown.dart';
import '../../activities/domain/activity_xp_calculator.dart';
import '../../xp/domain/base_xp_config.dart';

/// Settings → Categories: previews the existing XP rules without changing
/// their domain configuration or creating a second XP engine.
class XpCategoriesScreen extends StatefulWidget {
  const XpCategoriesScreen({super.key});

  @override
  State<XpCategoriesScreen> createState() => _XpCategoriesScreenState();
}

class _XpCategoriesScreenState extends State<XpCategoriesScreen> {
  static const _sources = [
    BaseXpSource.task,
    BaseXpSource.activity,
    BaseXpSource.subGoal,
    BaseXpSource.skill,
  ];
  static const _durationAnchors = [0, 15, 30, 60, 120, 240, 360, 480, 600, 720];
  final Map<BaseXpSource, int> _difficulty = {
    for (final source in _sources) source: 5,
  };
  int _durationMinutes = 120;

  int _baseXp(BaseXpSource source, int difficulty) => switch (source) {
    BaseXpSource.task => BaseXpConfig.forTask(difficulty),
    BaseXpSource.activity => ActivityXpCalculator.ceilingXp(difficulty),
    BaseXpSource.subGoal => BaseXpConfig.forSubGoal(difficulty),
    BaseXpSource.skill => BaseXpConfig.forSkill(difficulty),
  };

  String _name(BaseXpSource source) => switch (source) {
    BaseXpSource.task => 'TASK',
    BaseXpSource.activity => 'ACTIVITY',
    BaseXpSource.subGoal => 'SUB-GOAL',
    BaseXpSource.skill => 'SKILL',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020302),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CATEGORIES',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'XP RULES',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          for (final source in _sources) _ruleCard(source),
        ],
      ),
    );
  }

  Widget _ruleCard(BaseXpSource source) {
    final difficulty = _difficulty[source]!;
    final isActivity = source == BaseXpSource.activity;
    final ceiling = _baseXp(source, difficulty);
    final durationFactor = isActivity
        ? ActivityXpCalculator.durationFactor(_durationMinutes)
        : 1.0;
    final finalXp = isActivity
        ? ActivityXpCalculator.calculateActivityXp(
            difficulty,
            Duration(minutes: _durationMinutes),
          )
        : ceiling;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ActiveGlassCard(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _name(source),
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  'MAX ${BaseXpConfig.maxPointsFor(source)} XP',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isActivity
                  ? 'CEILING: ROUND(30 × DIFFICULTY / 10)'
                  : 'XP: ROUND(${BaseXpConfig.maxPointsFor(source)} × DIFFICULTY / 10)',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'DIFFICULTY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KratosDropdown<int>(
                    value: difficulty,
                    hint: 'Select difficulty',
                    isExpanded: true,
                    items: [
                      for (var value = 1; value <= 10; value++)
                        KratosDropdownItem(value: value, label: '$value / 10'),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _difficulty[source] = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    '$finalXp XP',
                    key: ValueKey('$finalXp-$durationFactor'),
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if (isActivity) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'SESSION DURATION · MAX 720 MIN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 138,
                    child: KratosDropdown<int>(
                      value: _durationMinutes,
                      hint: 'Duration',
                      isExpanded: true,
                      items: [
                        for (final minutes in _durationAnchors)
                          KratosDropdownItem(
                            value: minutes,
                            label: '$minutes min',
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _durationMinutes = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'FINAL XP: ROUND($ceiling × ${(durationFactor * 100).round()}%)',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final minutes in _durationAnchors)
                    Text(
                      '$minutes min · ${(ActivityXpCalculator.durationFactor(minutes) * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
