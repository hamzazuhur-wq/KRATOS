// ignore_for_file: public_member_api_docs
// Wave 9: Global Timer Banner & Floating Session Controls.
// Liquid Glass / Acid Lime aesthetic — remains visible across navigation.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../data/drift/app_database.dart';
import '../domain/global_timer_controller.dart';

class GlobalTimerBanner extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;

  const GlobalTimerBanner({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ActiveTimerState?>(
      stream: GlobalTimerController().stream,
      initialData: GlobalTimerController().currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final isPaused = state.isPaused;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isPaused
                    ? const Color(0xFFFF9500).withValues(alpha: 0.2)
                    : const Color(0xFFC6F135).withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openFloatingPanel(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0F0D).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPaused
                            ? const Color(0xFFFF9500).withValues(alpha: 0.6)
                            : const Color(0xFFC6F135).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isPaused
                                ? const Color(0xFFFF9500)
                                      .withValues(alpha: 0.15)
                                : const Color(0xFFC6F135)
                                      .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaused ? Icons.pause : Icons.timer,
                            color: isPaused
                                ? const Color(0xFFFF9500)
                                : const Color(0xFFC6F135),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '⏱ ${state.formattedTime}',
                          style: TextStyle(
                            color: isPaused
                                ? const Color(0xFFFF9500)
                                : const Color(0xFFC6F135),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.taskTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: () {
                            if (isPaused) {
                              GlobalTimerController().resumeTimer();
                            } else {
                              GlobalTimerController().pauseTimer();
                            }
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.stop,
                            color: Color(0xFFFF3B30),
                            size: 18,
                          ),
                          onPressed: () => _openFloatingPanel(context, state),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFloatingPanel(BuildContext context, ActiveTimerState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _FloatingTimerControlsSheet(database: database, ownerId: ownerId),
    );
  }
}

class _FloatingTimerControlsSheet extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const _FloatingTimerControlsSheet({
    required this.database,
    required this.ownerId,
  });

  @override
  State<_FloatingTimerControlsSheet> createState() =>
      _FloatingTimerControlsSheetState();
}

class _FloatingTimerControlsSheetState
    extends State<_FloatingTimerControlsSheet> {
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ActiveTimerState?>(
      stream: GlobalTimerController().stream,
      initialData: GlobalTimerController().currentState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return const SizedBox.shrink();
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F0D).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // Live Timer Display
                Text(
                  state.formattedTime,
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.isPaused ? 'PAUSED' : 'TIMING ON',
                  style: TextStyle(
                    color: state.isPaused
                        ? const Color(0xFFFF9500)
                        : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Context Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Color(0xFFC6F135),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Task: ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              state.taskTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (state.goalTitle != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.track_changes,
                              size: 16,
                              color: Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Goal: ',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                state.goalTitle!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Controls: Pause/Resume, Stop & Save, Discard
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (state.isPaused) {
                            GlobalTimerController().resumeTimer();
                          } else {
                            GlobalTimerController().pauseTimer();
                          }
                        },
                        icon: Icon(
                          state.isPaused ? Icons.play_arrow : Icons.pause,
                          size: 18,
                        ),
                        label: Text(state.isPaused ? 'Resume' : 'Pause'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveAndEndSession,
                        icon: const Icon(Icons.check, size: 18),
                        label: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF020302),
                                ),
                              )
                            : const Text(
                                'SAVE SESSION',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6F135),
                          foregroundColor: const Color(0xFF020302),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    GlobalTimerController().discard();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Discard Session',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndEndSession() async {
    setState(() => _isSaving = true);
    await GlobalTimerController().stopAndSaveSession(
      database: widget.database,
      ownerId: widget.ownerId,
      note: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session saved and XP recorded!'),
          backgroundColor: Color(0xFF141414),
        ),
      );
    }
  }
}
