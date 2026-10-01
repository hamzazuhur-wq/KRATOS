// ignore_for_file: public_member_api_docs
import 'dart:ui';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/number_pop_in.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../sessions/domain/global_active_session_controller.dart';
import '../../sessions/presentation/timer_status_badge.dart';
import '../data/activity_dashboard_repository.dart';
import '../domain/activity_models.dart';

class ActivityDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String activityId;

  const ActivityDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.activityId,
  });

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  late final ActivityDashboardRepository _repository;
  late final Stream<ActivityDetailData?> _detailStream;
  late final Stream<List<ActivitySessionLogItem>> _sessionsStream;

  @override
  void initState() {
    super.initState();
    _repository = ActivityDashboardRepository(widget.database);
    _detailStream = _repository.watchActivityDetail(
      ownerId: widget.ownerId,
      activityId: widget.activityId,
    );
    _sessionsStream = _repository.watchRecentSessions(
      activityId: widget.activityId,
    );
    GlobalActiveSessionController().bindDatabase(
      widget.database,
      widget.ownerId,
    );
  }

  Future<void> _handleDeleteActivity(ActivityDetailData activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
        ),
        title: const Text(
          'Delete Activity?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to delete "${activity.name}"? Historical sessions and earned XP will be safely preserved.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.softDeleteActivity(widget.activityId, widget.ownerId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _handleEditActivity(ActivityDetailData activity) async {
    final nameCtrl = TextEditingController(text: activity.name);
    final descCtrl = TextEditingController(text: activity.description ?? '');
    final durCtrl = TextEditingController(
      text:
          activity.targetDurationMinutes != null &&
              activity.targetDurationMinutes! > 0
          ? activity.targetDurationMinutes.toString()
          : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'Edit Activity',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NAME *',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'DESCRIPTION',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'TARGET DURATION (MINUTES)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: durCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. 30',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC6F135),
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final dur = int.tryParse(durCtrl.text.trim());

      await (widget.database.update(
        widget.database.activities,
      )..where((a) => a.id.equals(activity.id))).write(
        ActivitiesCompanion(
          name: Value(nameCtrl.text.trim()),
          description: Value(
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          ),
          targetDurationMinutes: Value(dur),
          versionHlc: Value(hlc),
          updatedAt: Value(now),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity updated successfully'),
            backgroundColor: Color(0xFF1E281E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'ACTIVITY DETAIL',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        actions: [
          StreamBuilder<ActivityDetailData?>(
            stream: _detailStream,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                tooltip: 'Edit Activity',
                onPressed: () => _handleEditActivity(data),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          StreamBuilder<ActivityDetailData?>(
            stream: _detailStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const KratosShimmer(
                  child: GenericDetailSkeleton(),
                );
              }

              final data = snapshot.data;
              if (data == null) {
                return const Center(
                  child: Text(
                    'Activity not found or deleted',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Header Card
                  _buildHeaderCard(data),
                  const SizedBox(height: 16),

                  // 2. Time Capture Card (Live Timer / Action Controls)
                  _buildTimeCaptureCard(data),
                  const SizedBox(height: 16),

                  // 3. Activity Summary Metrics
                  _buildSummaryCard(data),
                  const SizedBox(height: 16),

                  // 4. Recent Sessions
                  _buildRecentSessionsCard(),
                  const SizedBox(height: 16),

                  // 5. Related Context
                  _buildRelatedContextCard(data),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(ActivityDetailData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.local_activity,
                  color: Color(0xFFC6F135),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (data.lifeAreaName != null)
                          _buildBadge(
                            data.lifeAreaName!,
                            const Color(0xFFC6F135),
                          ),
                        if (data.categoryName != null)
                          _buildBadge(data.categoryName!, Colors.tealAccent),
                        if (data.targetDurationMinutes != null &&
                            data.targetDurationMinutes! > 0)
                          _buildBadge(
                            'Target ${data.formattedTargetDuration}',
                            Colors.amberAccent,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              KratosPopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                onSelected: (val) {
                  if (val == 'edit') _handleEditActivity(data);
                  if (val == 'delete') _handleDeleteActivity(data);
                },
                itemBuilder: (ctx) => [
                  const KratosPopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Edit Activity',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const KratosPopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete Activity',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (data.description != null && data.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              data.description!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeCaptureCard(ActivityDetailData data) {
    final controller = GlobalActiveSessionController();

    return StreamBuilder<ActiveSessionState?>(
      stream: controller.stream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final activeState = snapshot.data;
        final isThisActivityActive =
            activeState != null &&
            activeState.entityType == 'activity' &&
            activeState.entityId == data.id;

        final isPaused = isThisActivityActive && activeState.isPaused;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isThisActivityActive
                    ? const Color(0xFF0F1A0F).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isThisActivityActive
                      ? (isPaused
                            ? Colors.amber.withValues(alpha: 0.6)
                            : const Color(0xFFC6F135).withValues(alpha: 0.6))
                      : Colors.white.withValues(alpha: 0.08),
                  width: isThisActivityActive ? 1.5 : 1.0,
                ),
                boxShadow: isThisActivityActive
                    ? [
                        BoxShadow(
                          color:
                              (isPaused
                                      ? Colors.amber
                                      : const Color(0xFFC6F135))
                                  .withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isThisActivityActive
                                  ? (isPaused
                                        ? Colors.amber
                                        : const Color(0xFFC6F135))
                                  : Colors.white24,
                              boxShadow: isThisActivityActive
                                  ? [
                                      BoxShadow(
                                        color:
                                            (isPaused
                                                    ? Colors.amber
                                                    : const Color(0xFFC6F135))
                                                .withValues(alpha: 0.8),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(width: 8),
                          isThisActivityActive
                              ? TimerStatusBadge(isPaused: isPaused)
                              : const Text(
                                  'TIME CAPTURE',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ],
                      ),
                      if (data.targetDurationMinutes != null &&
                          data.targetDurationMinutes! > 0)
                        Text(
                          'Target: ${data.formattedTargetDuration}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Timer Display
                  Center(
                    child: Text(
                      isThisActivityActive
                          ? activeState.formattedElapsed
                          : '00:00:00',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: isThisActivityActive
                            ? (isPaused ? Colors.amber : Colors.white)
                            : Colors.white38,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  if (!isThisActivityActive) ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              controller.startSession(
                                entityType: 'activity',
                                entityId: data.id,
                                title: data.name,
                                lifeAreaId: data.lifeAreaId,
                                lifeAreaName: data.lifeAreaName,
                                categoryName: data.categoryName,
                                targetDurationMinutes:
                                    data.targetDurationMinutes ?? 0,
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Color(0xFF0D0D0D),
                              size: 20,
                            ),
                            label: const Text(
                              'START TIMER',
                              style: TextStyle(
                                color: Color(0xFF0D0D0D),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6F135),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final repo = ActivityDashboardRepository(
                                widget.database,
                              );
                              final earned = await repo.quickLogSession(
                                activityId: data.id,
                                ownerId: widget.ownerId,
                                durationMinutes:
                                    data.targetDurationMinutes ?? 30,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF141F14),
                                    content: Text(
                                      'Session logged! +$earned XP awarded to ${data.lifeAreaName ?? 'Life Area'}.',
                                      style: const TextStyle(
                                        color: Color(0xFFC6F135),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFFC6F135),
                              size: 18,
                            ),
                            label: const Text(
                              'LOG (+XP)',
                              style: TextStyle(
                                color: Color(0xFFC6F135),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFC6F135),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: isPaused
                              ? ElevatedButton.icon(
                                  onPressed: () => controller.resumeSession(),
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    color: Color(0xFF0D0D0D),
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'RESUME',
                                    style: TextStyle(
                                      color: Color(0xFF0D0D0D),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC6F135),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => controller.pauseSession(),
                                  icon: const Icon(
                                    Icons.pause,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'PAUSE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await controller.completeSession(
                                database: widget.database,
                                ownerId: widget.ownerId,
                              );
                              if (result != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF141F14),
                                    content: Text(
                                      'Session completed! +${result['xpEarned']} XP awarded.',
                                      style: const TextStyle(
                                        color: Color(0xFFC6F135),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF0D0D0D),
                              size: 18,
                            ),
                            label: const Text(
                              'COMPLETE',
                              style: TextStyle(
                                color: Color(0xFF0D0D0D),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6F135),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => controller.stopSession(
                            database: widget.database,
                            ownerId: widget.ownerId,
                          ),
                          icon: const Icon(
                            Icons.stop_circle_outlined,
                            color: Colors.white54,
                            size: 28,
                          ),
                          tooltip: 'Stop session',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(ActivityDetailData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVITY METRICS & STATS',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Total Sessions',
                  '${data.totalSessions}',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Total Time',
                  data.formattedTotalDuration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Avg Session',
                  data.formattedAverageDuration,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'XP Earned',
                  '+${data.totalXpEarned} XP',
                ),
              ),
            ],
          ),
          if (data.lastSessionAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Last active: ${DateFormat.yMMMd().add_jm().format(data.lastSessionAt!.toLocal())}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT SESSIONS',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<ActivitySessionLogItem>>(
            stream: _sessionsStream,
            builder: (context, snapshot) {
              final sessions = snapshot.data ?? [];
              if (sessions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No completed sessions yet. Start a focus session above to record time and earn XP.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 16,
                ),
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFFC6F135),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMd().add_jm().format(
                                s.startedAt.toLocal(),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (s.note != null && s.note!.isNotEmpty)
                              Text(
                                s.note!,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        s.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+${s.xpEarned} XP',
                          style: const TextStyle(
                            color: Color(0xFFC6F135),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedContextCard(ActivityDetailData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RELATED CONTEXT & SKILLS',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (data.skillNames.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: data.skillNames
                  .map((s) => _buildBadge('⚡ $s', Colors.cyanAccent))
                  .toList(),
            ),
          ] else ...[
            const Text(
              'No linked skills attached to this activity.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 4),
          KratosNumberPopIn(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
