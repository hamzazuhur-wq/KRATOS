// Wave 20: Vision Proposal Confirmation Modal — Liquid Glass aesthetic.
// Enforces Invariant #11: AI output is never ground truth without explicit user confirmation.

import 'package:flutter/material.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../domain/multimodal_models.dart';

class VisionProposalDialog extends StatelessWidget {
  final VisionAnalysisResult result;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const VisionProposalDialog({
    super.key,
    required this.result,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.remove_red_eye_outlined, color: lime, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI VISION PROPOSAL',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: lime,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedColor, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onDismiss,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  result.detectedActivity,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.rawExplanation,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: mutedColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lime.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: lime.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PROPOSED REWARD',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '+${result.proposedXp} XP',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: lime,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onDismiss,
                      child: Text(
                        'Reject',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KratosPressable(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'ACCEPT & RECORD XP',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: isDark ? const Color(0xFF020302) : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
