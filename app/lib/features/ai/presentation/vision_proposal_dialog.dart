// Wave 20: Vision Proposal Confirmation Modal — Liquid Glass aesthetic.
// Enforces Invariant #11: AI output is never ground truth without explicit user confirmation.

import 'package:flutter/material.dart';
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: Row(
        children: [
          const Icon(Icons.remove_red_eye_outlined, color: Color(0xFFC6F135), size: 22),
          const SizedBox(width: 8),
          const Text(
            'AI VISION PROPOSAL',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.detectedActivity,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            result.rawExplanation,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFC6F135).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC6F135).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Proposed Reward:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  '+${result.proposedXp} XP',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text('Reject', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC6F135),
            foregroundColor: const Color(0xFF0D0D0D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Accept & Record XP', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
