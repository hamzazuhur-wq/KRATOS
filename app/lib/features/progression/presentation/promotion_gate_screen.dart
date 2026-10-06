// ignore_for_file: public_member_api_docs
// Wave 22: PromotionGateScreen — Liquid Glass widget showing compound gate status
// for a Life Area level promotion (ADR-010).
//
// Design: Dark Volcanic (#0D0D0D) + Acid Lime (#C6F135) + Liquid Glass panels.

import 'package:flutter/material.dart';
import '../domain/achievement_gate_models.dart';
import '../domain/achievement_gate_service.dart';
import '../data/progression_dao.dart';
import '../../../data/drift/app_database.dart';

class PromotionGateScreen extends StatefulWidget {
  final String userId;
  final String lifeAreaId;
  final String lifeAreaName;
  final int totalXp;
  final AppDatabase db;
  final ProgressionDao progressionDao;

  const PromotionGateScreen({
    super.key,
    required this.userId,
    required this.lifeAreaId,
    required this.lifeAreaName,
    required this.totalXp,
    required this.db,
    required this.progressionDao,
  });

  @override
  State<PromotionGateScreen> createState() => _PromotionGateScreenState();
}

class _PromotionGateScreenState extends State<PromotionGateScreen> {
  late final AchievementGateService _gateService;
  PromotionGateResult? _result;
  bool _loading = true;
  bool _promoting = false;

  @override
  void initState() {
    super.initState();
    _gateService = AchievementGateService(
      progressionDao: widget.progressionDao,
      db: widget.db,
    );
    _load();
  }

  Future<void> _load() async {
    final result = await _gateService.evaluate(
      userId: widget.userId,
      lifeAreaId: widget.lifeAreaId,
      totalXp: widget.totalXp,
    );
    if (mounted) setState(() { _result = result; _loading = false; });
  }

  Future<void> _executePromotion(int nextLevel) async {
    setState(() => _promoting = true);
    final promoted = await _gateService.executePromotion(
      userId: widget.userId,
      lifeAreaId: widget.lifeAreaId,
      newLevel: nextLevel,
      versionHlc: DateTime.now().toUtc().toIso8601String(),
    );
    if (!mounted) return;
    await _load();
    _showPromotedDialog(promoted);
  }

  void _showPromotedDialog(PromotionGatePromoted promoted) {
    showDialog<void>(
      context: context,
      builder: (_) => _LiquidGlassDialog(
        icon: Icons.arrow_upward_rounded,
        iconColor: const Color(0xFFC6F135),
        title: 'Level Up! 🎉',
        body: 'You\'ve reached Level ${promoted.newLevel} in ${widget.lifeAreaName}!',
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${widget.lifeAreaName} — Promotion Gate',
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC6F135)),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _XpGaugeCard(result: result),
          const SizedBox(height: 16),
          if (result is PromotionGateLocked || result is PromotionGatePendingObjectives)
            _ObjectivesCard(
              objectives: switch (result) {
                final PromotionGateLocked r => r.objectives,
                final PromotionGatePendingObjectives r => r.objectives,
                _ => const [],
              },
            ),
          if (result case final PromotionGateReady ready) ...[
            _ObjectivesCard(objectives: ready.objectives),
            const SizedBox(height: 16),
            _PromoteButton(
              promoting: _promoting,
              nextLevel: ready.nextLevel,
              onTap: () => _executePromotion(ready.nextLevel),
            ),
          ],
          if (result case final PromotionGatePromoted promoted)
            _AlreadyPromotedBanner(newLevel: promoted.newLevel),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _XpGaugeCard extends StatelessWidget {
  final PromotionGateResult result;
  const _XpGaugeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final (int current, int required, double progress, int level) = switch (result) {
      PromotionGateLocked r => (r.currentXp, r.requiredXp, r.xpProgress, r.currentLevel),
      PromotionGatePendingObjectives r => (r.currentXp, r.requiredXp, 1.0, r.currentLevel),
      PromotionGateReady r => (r.currentXp, r.currentXp, 1.0, r.currentLevel),
      PromotionGatePromoted r => (0, 0, 1.0, r.newLevel),
    };

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFC6F135), size: 20),
              const SizedBox(width: 8),
              const Text(
                'XP Threshold',
                style: TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                'Level $level',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? const Color(0xFFC6F135) : Colors.white38,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current XP',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (required > 0)
                Text(
                  '/ $required XP required',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ObjectivesCard extends StatelessWidget {
  final List<PromotionObjective> objectives;
  const _ObjectivesCard({required this.objectives});

  @override
  Widget build(BuildContext context) {
    if (objectives.isEmpty) {
      return _GlassCard(
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xFFC6F135), size: 18),
            SizedBox(width: 10),
            Text(
              'No mandatory objectives for this level.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mandatory Objectives',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...objectives.map((obj) => _ObjectiveTile(objective: obj)),
        ],
      ),
    );
  }
}

class _ObjectiveTile extends StatelessWidget {
  final PromotionObjective objective;
  const _ObjectiveTile({required this.objective});

  @override
  Widget build(BuildContext context) {
    final done = objective.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? const Color(0xFFC6F135) : Colors.white24,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  objective.title,
                  style: TextStyle(
                    color: done ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (objective.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      objective.description,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoteButton extends StatelessWidget {
  final bool promoting;
  final int nextLevel;
  final VoidCallback onTap;

  const _PromoteButton({
    required this.promoting,
    required this.nextLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: promoting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: promoting
              ? const Color(0xFFC6F135).withAlpha(100)
              : const Color(0xFFC6F135),
          borderRadius: BorderRadius.circular(16),
          boxShadow: promoting
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFC6F135).withAlpha(70),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (promoting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0D0D0D),
                ),
              )
            else
              const Icon(Icons.arrow_upward_rounded, color: Color(0xFF0D0D0D), size: 20),
            const SizedBox(width: 10),
            Text(
              promoting ? 'Promoting...' : 'Promote to Level $nextLevel',
              style: const TextStyle(
                color: Color(0xFF0D0D0D),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlreadyPromotedBanner extends StatelessWidget {
  final int newLevel;
  const _AlreadyPromotedBanner({required this.newLevel});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFC6F135), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Already promoted!',
                  style: TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'You are now at Level $newLevel.',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: child,
    );
  }
}

class _LiquidGlassDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  const _LiquidGlassDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131313),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Color(0xFF0D0D0D),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
