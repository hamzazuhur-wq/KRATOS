// ignore_for_file: public_member_api_docs
// Wave 27: LiveActivityWidget — Liquid Glass dynamic island & lock-screen session pill.

import 'package:flutter/material.dart';
import '../domain/live_activity_service.dart';

class LiveActivityWidget extends StatelessWidget {
  final LiveSessionState state;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  const LiveActivityWidget({
    super.key,
    required this.state,
    required this.onTogglePause,
    required this.onStop,
  });

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFC6F135).withAlpha(100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC6F135).withAlpha(30),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.isPaused ? Colors.amber : const Color(0xFFC6F135),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (state.lifeAreaName != null)
                      Text(
                        state.lifeAreaName!,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Text(
                _formatTime(state.remainingSeconds),
                style: const TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: onTogglePause,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 20),
                onPressed: onStop,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: state.progressPct,
              minHeight: 4,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC6F135)),
            ),
          ),
        ],
      ),
    );
  }
}
