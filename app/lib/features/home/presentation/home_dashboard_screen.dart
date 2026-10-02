import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/kratos_tiers.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_motion.dart';
import '../../../data/drift/app_database.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/profile_models.dart';
import '../../progression/data/overall_progression_repository.dart';
import '../data/home_dashboard_repository.dart';
import '../domain/home_models.dart';
import 'widgets/ending_today_section.dart';
import 'widgets/life_area_level_card.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/dashboard_status_cards.dart';
import 'widgets/xp_summary_card.dart';

/// KRATOS Main Home Dashboard / Command Center.
/// Gives the user a real, curated overview across the entire KRATOS system.
class HomeDashboardScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final void Function(int tabIndex)? onNavigateTab;
  final bool useRichCaption;
  final HomeDashboardData? initialData;

  const HomeDashboardScreen({
    super.key,
    required this.database,
    required this.ownerId,
    this.onNavigateTab,
    this.useRichCaption = false,
    this.initialData,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _ProgressionIdentityBlock extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;
  final UserProfileData profile;
  final VoidCallback onEditSentence;

  const _ProgressionIdentityBlock({
    required this.database,
    required this.ownerId,
    required this.profile,
    required this.onEditSentence,
  });

  @override
  Widget build(BuildContext context) {
    final hasCaption = profile.caption?.trim().isNotEmpty ?? false;
    return StreamBuilder<OverallProgressionSnapshot>(
      stream: OverallProgressionRepository(database).watch(ownerId),
      builder: (context, snapshot) {
        final progression = snapshot.data;
        if (progression == null) {
          return KratosShimmer(
            child: Container(
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );
        }

        final global = progression.global;
        final tier = global.currentLevel.name;
        final tierColor = KratosTierSystem.getGlobalColor(tier);
        return KratosGlassCard(
          dashboardGlass: true,
          accentColor: tierColor,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 9,
                runSpacing: 6,
                children: [
                  Text(
                    tier.toUpperCase(),
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    global.currentLevel.romanNumeral,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(global.overallXp)} XP',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (hasCaption) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: onEditSentence,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.caption!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit_outlined,
                          color: Colors.white30,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late final HomeDashboardRepository _repository;
  late final Stream<HomeDashboardData> _dashboardStream;

  @override
  void initState() {
    super.initState();
    _repository = HomeDashboardRepository(widget.database);
    _dashboardStream = _repository.watchHomeDashboard(widget.ownerId);
  }

  void _editPreferredSentence(UserProfileData profile) {
    final controller = TextEditingController(text: profile.caption ?? '');
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF111411),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'Personal Caption / Sentence',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your preferred motto or focus sentence displayed on Home:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g. Build the life you actually want.',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFC6F135),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC6F135),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final newCaption = controller.text.trim().isNotEmpty
                  ? controller.text.trim()
                  : null;
              final repo = ProfileRepository(database: widget.database);
              await repo.updateProfile(
                userId: widget.ownerId,
                displayName: profile.displayName,
                caption: newCaption,
                avatarUrl: profile.avatarUrl,
              );
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
            },
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          StreamBuilder<HomeDashboardData>(
            initialData: widget.initialData,
            stream: _dashboardStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load dashboard: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }
              final isLoading = !snapshot.hasData;
              final data = snapshot.data;

              return SafeArea(
                child: SkeletonReveal(
                  loading: isLoading,
                  skeleton: const HomeDashboardSkeleton(),
                  child: data == null
                      ? const SizedBox.shrink()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 840;
                            return KratosPageEntrance(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isWide ? 32 : 18,
                                  vertical: 16,
                                ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Progression identity uses the same aggregate source as
                                  // the global header and Levels surfaces.
                                  _ProgressionIdentityBlock(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                    profile: data.profile,
                                    onEditSentence: () =>
                                        _editPreferredSentence(data.profile),
                                  ),
                                  const SizedBox(height: 18),

                                  XpSummaryCard(
                                    progression: data.aggregateProgression,
                                  ),
                                  const SizedBox(height: 12),
                                  DashboardStatusCards(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                    summary: data.workSummary,
                                    streakInfo: data.streakInfo,
                                    onNavigateTab: widget.onNavigateTab,
                                  ),
                                  const SizedBox(height: 12),
                                  DashboardNotificationsCard(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                  ),
                                  const SizedBox(height: 24),

                                  // 3. Quick Actions Row
                                  QuickActionsRow(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                  ),
                                  const SizedBox(height: 28),

                                  // 4. Life Area Levels Section
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.layers_outlined,
                                        color: Colors.white54,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'LIFE AREA LEVELS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          shadows: [
                                            Shadow(
                                              color: Color(0x44C6F135),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  if (data.lifeAreaEntries.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.02,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'No active Life Areas found',
                                          style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    )
                                  else if (isWide)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 14,
                                            mainAxisExtent: 104,
                                          ),
                                      itemCount: data.lifeAreaEntries.length,
                                      itemBuilder: (context, index) {
                                        return LifeAreaLevelCard(
                                          database: widget.database,
                                          ownerId: widget.ownerId,
                                          entry: data.lifeAreaEntries[index],
                                        );
                                      },
                                    )
                                  else
                                    Column(
                                      children: data.lifeAreaEntries.map((
                                        entry,
                                      ) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: LifeAreaLevelCard(
                                            database: widget.database,
                                            ownerId: widget.ownerId,
                                            entry: entry,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 28),

                                  // 5. Ending Today Section
                                  EndingTodaySection(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                    items: data.endingTodayItems,
                                    onNavigateTab: widget.onNavigateTab,
                                  ),
                                  const SizedBox(height: 28),

                                  // 6. Recent Section
                                  RecentActivitySection(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                    items: data.recentItems,
                                    onNavigateTab: widget.onNavigateTab,
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          );
                          },
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
