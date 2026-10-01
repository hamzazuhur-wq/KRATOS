// ignore_for_file: public_member_api_docs
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../data/drift/app_database.dart';
import '../domain/global_active_session_controller.dart';

class GlobalActiveSessionMiniPlayer extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final Function(String entityType, String entityId)? onOpenDetail;

  const GlobalActiveSessionMiniPlayer({
    super.key,
    required this.database,
    required this.ownerId,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final controller = GlobalActiveSessionController();
    controller.bindDatabase(database, ownerId);

    return StreamBuilder<ActiveSessionState?>(
      stream: controller.stream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final hasTarget = state.targetDurationSeconds > 0;
        final targetStr = hasTarget ? ' / ${state.formattedTarget}' : '';

        return Positioned(
          bottom: 75,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0F0A).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: state.isPaused
                          ? Colors.amber.withValues(alpha: 0.4)
                          : const Color(0xFFC6F135).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (state.isPaused ? Colors.amber : const Color(0xFFC6F135))
                            .withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          if (onOpenDetail != null) {
                            onOpenDetail!(state.entityType, state.entityId);
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: state.isPaused ? Colors.amber : const Color(0xFFC6F135),
                                boxShadow: [
                                  BoxShadow(
                                    color: (state.isPaused ? Colors.amber : const Color(0xFFC6F135))
                                        .withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.title.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: state.isPaused ? Colors.amber : const Color(0xFFC6F135),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  if (state.lifeAreaName != null && state.lifeAreaName!.isNotEmpty)
                                    Text(
                                      state.lifeAreaName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${state.formattedElapsed}$targetStr',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (state.isPaused)
                            TextButton.icon(
                              onPressed: () => controller.resumeSession(),
                              icon: const Icon(Icons.play_arrow, size: 14, color: Color(0xFFC6F135)),
                              label: const Text('Resume', style: TextStyle(color: Color(0xFFC6F135), fontSize: 11)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => controller.pauseSession(),
                              icon: const Icon(Icons.pause, size: 14, color: Colors.amber),
                              label: const Text('Pause', style: TextStyle(color: Colors.amber, fontSize: 11)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          const SizedBox(width: 6),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final result = await controller.completeSession(
                                database: database,
                                ownerId: ownerId,
                              );
                              if (result != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF141F14),
                                    content: Text(
                                      'Session completed! +${result['xpEarned']} XP awarded.',
                                      style: const TextStyle(color: Color(0xFFC6F135)),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF0D0D0D)),
                            label: const Text(
                              'Complete',
                              style: TextStyle(
                                color: Color(0xFF0D0D0D),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6F135),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => controller.stopSession(database: database, ownerId: ownerId),
                            icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.white38),
                            tooltip: 'Stop session without full completion',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
