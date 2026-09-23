// ignore_for_file: public_member_api_docs
// Wave 25: AICoachSheet — Liquid Glass coaching modal with burnout meter.

import 'package:flutter/material.dart';
import '../domain/coach_models.dart';

class AICoachSheet extends StatelessWidget {
  final CoachRecommendation recommendation;
  final VoidCallback onAcceptAction;
  final VoidCallback onDismiss;

  const AICoachSheet({
    super.key,
    required this.recommendation,
    required this.onAcceptAction,
    required this.onDismiss,
  });

  Color _riskColor(BurnoutRiskLevel risk) {
    switch (risk) {
      case BurnoutRiskLevel.low:
        return const Color(0xFFC6F135); // Acid Lime
      case BurnoutRiskLevel.moderate:
        return Colors.amberAccent;
      case BurnoutRiskLevel.elevated:
        return Colors.orangeAccent;
      case BurnoutRiskLevel.critical:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(recommendation.riskLevel);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF131313),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: color, size: 28),
              const SizedBox(width: 10),
              Text(
                'AI Habit Coach',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(
                  recommendation.riskLevel.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fatigue Meter
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fatigue Index', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text(
                    '${(recommendation.fatigueScore * 100).toInt()}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: recommendation.fatigueScore,
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            recommendation.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.explanation,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: onDismiss,
                  child: const Text('Dismiss', style: TextStyle(color: Colors.white38)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: const Color(0xFF0D0D0D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onAcceptAction,
                  child: Text(
                    recommendation.suggestedActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
