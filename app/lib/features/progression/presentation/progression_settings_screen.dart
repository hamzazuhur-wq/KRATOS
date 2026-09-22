// Wave 6: Progression Settings screen.
// Displays the 6-tier ladder, level curves preview, and compound progression metrics.
// Liquid Glass / Dark Volcanic / Acid Lime aesthetic.

import 'package:flutter/material.dart';
import '../domain/progression_calculator.dart';
import '../domain/progression_models.dart';

class ProgressionSettingsScreen extends StatefulWidget {
  const ProgressionSettingsScreen({super.key});

  @override
  State<ProgressionSettingsScreen> createState() =>
      _ProgressionSettingsScreenState();
}

class _ProgressionSettingsScreenState extends State<ProgressionSettingsScreen> {
  int _sampleXp = 4500;

  @override
  Widget build(BuildContext context) {
    final info = ProgressionCalculator.calculate(totalXp: _sampleXp);
    final tiers = ProgressionCalculator.defaultTiers;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PROGRESSION & TIERS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Interactive Preview Card
          _buildProgressionCard(info),
          const SizedBox(height: 24),

          // 2. XP Simulator Slider
          _buildSimulatorControl(),
          const SizedBox(height: 28),

          // 3. Tiers Ladder Header
          const Text(
            'TIER DEFINITIONS LADDER',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),

          // 4. Tier List
          ...tiers.map(_buildTierTile),
        ],
      ),
    );
  }

  Widget _buildProgressionCard(ProgressionInfo info) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC6F135).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LEVEL ${info.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC6F135)),
                ),
                child: Text(
                  info.tier.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: info.progressPct / 100.0,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC6F135)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP: ${info.totalXp}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                'Next: ${info.xpInLevel} / ${info.xpToNext} XP (${info.progressPct}%)',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIMULATED TOTAL XP',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '$_sampleXp XP',
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: _sampleXp.toDouble(),
            min: 0,
            max: 70000,
            divisions: 140,
            activeColor: const Color(0xFFC6F135),
            inactiveColor: Colors.white12,
            onChanged: (val) {
              setState(() {
                _sampleXp = val.toInt();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTierTile(TierDefinitionSnapshot tier) {
    final isReached = _sampleXp >= tier.entryXp;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isReached
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReached
              ? const Color(0xFFC6F135).withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isReached ? Icons.military_tech : Icons.shield_outlined,
                color: isReached ? const Color(0xFFC6F135) : Colors.white24,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                tier.name,
                style: TextStyle(
                  color: isReached ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Text(
            '${tier.entryXp} XP',
            style: TextStyle(
              color: isReached ? const Color(0xFFC6F135) : Colors.white24,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
