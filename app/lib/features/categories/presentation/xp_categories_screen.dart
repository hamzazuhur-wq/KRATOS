import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../activities/domain/activity_xp_calculator.dart';
import '../../settings/presentation/settings_kit.dart';
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
    return SettingsPage(
      title: 'Categories',
      children: [
        const SettingsSectionHeader(title: 'XP Rules'),
        for (final source in _sources) _ruleCard(source),
      ],
    );
  }

  Widget _ruleCard(BaseXpSource source) {
    final t = SettingsTokens.of(context);
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

    final labelStyle = TextStyle(
      fontFamily: 'IBM Plex Mono',
      color: t.secondary,
      fontSize: 10.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SettingsGroup(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _name(source),
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: t.accentText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SettingsStatusPill(
                    label: 'Max ${BaseXpConfig.maxPointsFor(source)} XP',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isActivity
                    ? 'CEILING: ROUND(30 × DIFFICULTY / 10)'
                    : 'XP: ROUND(${BaseXpConfig.maxPointsFor(source)} × DIFFICULTY / 10)',
                style: labelStyle.copyWith(color: t.muted, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('DIFFICULTY', style: labelStyle),
                  const SizedBox(width: 12),
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
                  const SizedBox(width: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      '$finalXp XP',
                      key: ValueKey('$finalXp-$durationFactor'),
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: t.accentText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (isActivity) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SESSION DURATION · MAX 720 MIN',
                        style: labelStyle,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                const SizedBox(height: 10),
                Text(
                  'FINAL XP: ROUND($ceiling × ${(durationFactor * 100).round()}%)',
                  style: labelStyle.copyWith(color: t.text),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final minutes in _durationAnchors)
                      Text(
                        '$minutes min · ${(ActivityXpCalculator.durationFactor(minutes) * 100).round()}%',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: minutes == _durationMinutes
                              ? t.accentText
                              : t.muted,
                          fontWeight: minutes == _durationMinutes
                              ? FontWeight.w700
                              : FontWeight.w400,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
