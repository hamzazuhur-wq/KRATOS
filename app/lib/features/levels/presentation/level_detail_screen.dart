import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_tiers.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_theme.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../data/drift/app_database.dart';
import '../../life_areas/presentation/life_area_dashboard_screen.dart';
import '../data/level_detail_repository.dart';
import '../data/levels_dashboard_repository.dart';

/// Level Detail Dashboard for a single specific Level definition.
///
/// Displays:
/// - Level name, Tier, Category, XP range, Description, progression range
/// - Real linked Life Areas currently sitting at this Level
/// - Edit Level functionality (persisted to Drift database)
class LevelDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final int level;
  final LevelDetailData? initialData;
  final Stream<LevelDetailData>? dataStream;

  const LevelDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.level,
    this.initialData,
    this.dataStream,
  });

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  late final LevelDetailRepository _repository;
  late Stream<LevelDetailData> _dataStream;
  bool _errorLogged = false;

  @override
  void initState() {
    super.initState();
    _repository = LevelDetailRepository(widget.database);
    _dataStream =
        widget.dataStream ??
        _repository.watchLevelDetail(
          level: widget.level,
          ownerId: widget.ownerId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KratosTheme.volcanic,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'LEVEL DETAIL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 15,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          StreamBuilder<LevelDetailData>(
            stream: _dataStream,
            initialData: widget.initialData,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                _logError(snapshot.error, snapshot.stackTrace);
                return _ErrorState(onRetry: _reload);
              }

              if (!snapshot.hasData) {
                return const _LoadingState();
              }

              final data = snapshot.data!;
              final tierColor = KratosTierSystem.getColor(
                data.tier,
                data.tierColor,
              );

              return RefreshIndicator(
                onRefresh: () async => _reload(),
                color: KratosTheme.acidLime,
                backgroundColor: const Color(0xFF1E1E1E),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    // 1. Header Banner & Action
                    _buildHeader(data, tierColor),
                    const SizedBox(height: 18),

                    // 2. Primary Liquid Glass Information Card
                    _buildLevelInfoCard(data, tierColor),
                    const SizedBox(height: 18),

                    // 3. Progression Track Visualization
                    _buildProgressionTrackCard(data, tierColor),
                    const SizedBox(height: 24),

                    // 4. Linked Life Areas Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LIFE AREAS USING THIS LEVEL',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${data.linkedLifeAreas.length} Active',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 5. Linked Life Areas List or Empty State
                    if (data.linkedLifeAreas.isEmpty)
                      _EmptyLinkedLifeAreasState(levelName: data.name)
                    else
                      ...data.linkedLifeAreas.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LinkedLifeAreaCard(
                            entry: entry,
                            tierColor: tierColor,
                            onTap: () => _openLifeAreaDashboard(entry),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LevelDetailData data, Color tierColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tier Icon Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: tierColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            KratosTierSystem.getIcon(data.tier),
            color: tierColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),

        // Title & Category
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      data.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tierColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      data.tier.toUpperCase(),
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: data.category != null
                        ? KratosTheme.acidLime
                        : Colors.white38,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    data.category?.name ?? 'No Category Assigned',
                    style: TextStyle(
                      color: data.category != null
                          ? Colors.white70
                          : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Edit Button
        OutlinedButton.icon(
          onPressed: () => _openEditDialog(data),
          icon: const Icon(
            Icons.edit_outlined,
            size: 15,
            color: KratosTheme.acidLime,
          ),
          label: const Text(
            'Edit',
            style: TextStyle(
              color: KratosTheme.acidLime,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: KratosTheme.acidLime.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelInfoCard(LevelDetailData data, Color tierColor) {
    return KratosGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tierColor.withValues(alpha: 0.2)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tierColor.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'LEVEL SPECIFICATION',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  'Level ${data.level}',
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (data.description != null &&
                data.description!.trim().isNotEmpty) ...[
              Text(
                data.description!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Specification Grid
            Row(
              children: [
                Expanded(
                  child: _buildSpecTile(
                    label: 'XP RANGE',
                    value:
                        '${_formatXp(data.lowerXp)} â†’ ${_formatXp(data.upperXp)} XP',
                    subtext: '${_formatXp(data.deltaXp)} XP Span',
                    accentColor: tierColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSpecTile(
                    label: 'CATEGORY',
                    value: data.category?.name ?? 'None',
                    subtext: data.category != null ? 'Active' : 'Unassigned',
                    accentColor: data.category != null
                        ? KratosTheme.acidLime
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressionTrackCard(LevelDetailData data, Color tierColor) {
    return KratosGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROGRESSION BRACKET',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  tierColor.withValues(alpha: 0.8),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatXp(data.lowerXp)} XP (Entry)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  '${_formatXp(data.upperXp)} XP (Next Level)',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecTile({
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  void _openEditDialog(LevelDetailData data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditLevelSheet(
        database: widget.database,
        ownerId: widget.ownerId,
        data: data,
        onSave: (updated) async {
          await _repository.updateLevel(
            level: updated.level,
            name: updated.name,
            description: updated.description,
            categoryId: updated.category?.id,
            tierName: updated.tier,
            deltaXp: updated.deltaXp,
            cumulativeXpRequired: updated.lowerXp,
          );
          _reload();
        },
      ),
    );
  }

  void _openLifeAreaDashboard(LevelsDashboardEntry entry) {
    Navigator.of(context).push(
      KratosMaterialPageRoute<void>(
        builder: (_) => LifeAreaDashboardScreen(
          database: widget.database,
          ownerId: widget.ownerId,
          area: entry.area,
        ),
      ),
    );
  }

  void _logError(Object? error, StackTrace? stackTrace) {
    if (_errorLogged) return;
    _errorLogged = true;
    developer.log(
      'Level detail failed to load',
      name: 'kratos.level_detail',
      error: error,
      stackTrace: stackTrace,
    );
    if (error != null) TelemetryService().recordError(error, stackTrace);
  }

  void _reload() {
    setState(() {
      _errorLogged = false;
      _dataStream = _repository.watchLevelDetail(
        level: widget.level,
        ownerId: widget.ownerId,
      );
    });
  }

  String _formatXp(int xp) {
    if (xp >= 1000000) return '${(xp / 1000000).toStringAsFixed(1)}M';
    if (xp >= 1000) {
      final formatted = (xp / 1000).toStringAsFixed(xp % 1000 == 0 ? 0 : 1);
      return '${formatted}K';
    }
    return '$xp';
  }
}

/// Card showing an active Life Area linked to this Level.
class _LinkedLifeAreaCard extends StatelessWidget {
  final LevelsDashboardEntry entry;
  final Color tierColor;
  final VoidCallback onTap;

  const _LinkedLifeAreaCard({
    required this.entry,
    required this.tierColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progression = entry.progression;
    final remaining = progression.xpToNext == 0
        ? null
        : progression.xpToNext - progression.xpInLevel;

    return KratosGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.area.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Text(
                    '${progression.totalXp} XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, color: tierColor, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.category?.name ?? 'No category',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progression.progressPct / 100,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progression.progressPct.toStringAsFixed(0)}% in level',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    remaining == null
                        ? 'Max Level'
                        : '$remaining XP to Level ${progression.level + 1}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state when no Life Areas are currently sitting at this Level.
class _EmptyLinkedLifeAreasState extends StatelessWidget {
  final String levelName;
  const _EmptyLinkedLifeAreasState({required this.levelName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.nature_people_outlined,
            color: Colors.white24,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'NO ACTIVE LIFE AREAS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No Life Areas are currently using this Level.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator state.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(48.0),
      child: CircularProgressIndicator(color: KratosTheme.acidLime),
    ),
  );
}

/// Error state with retry callback.
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white38,
            size: 42,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load Level Detail.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: KratosTheme.acidLime,
              foregroundColor: Colors.black,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

/// Bottom sheet dialog for editing Level definition fields.
class _EditLevelSheet extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final LevelDetailData data;
  final ValueChanged<LevelDetailData> onSave;

  const _EditLevelSheet({
    required this.database,
    required this.ownerId,
    required this.data,
    required this.onSave,
  });

  @override
  State<_EditLevelSheet> createState() => _EditLevelSheetState();
}

class _EditLevelSheetState extends State<_EditLevelSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _minXpController;
  late final TextEditingController _maxXpController;
  late final LevelDetailRepository _repository;

  List<Category> _categories = [];
  List<TierDefinition> _tiers = [];
  String? _selectedCategoryId;
  String _selectedTier = 'Bronze';
  bool _loading = true;
  String? _errorMessage;

  int _currentMinXp = 1000;
  int _currentMaxXp = 3000;

  @override
  void initState() {
    super.initState();
    _repository = LevelDetailRepository(widget.database);
    _nameController = TextEditingController(text: widget.data.name);
    _descController = TextEditingController(
      text: widget.data.description ?? '',
    );
    _selectedCategoryId = widget.data.category?.id;
    _selectedTier = widget.data.tier;
    _currentMinXp = widget.data.lowerXp;
    _currentMaxXp = widget.data.upperXp;
    _minXpController = TextEditingController(text: '$_currentMinXp');
    _maxXpController = TextEditingController(text: '$_currentMaxXp');
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    final categories = await _repository.getCategories(widget.ownerId);
    final tiers = await _repository.getTiers();
    if (mounted) {
      setState(() {
        _categories = categories;
        _tiers = tiers;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _minXpController.dispose();
    _maxXpController.dispose();
    super.dispose();
  }

  void _onTierChanged(String newTier) {
    setState(() {
      _selectedTier = newTier;
      final boundary = KratosTierSystem.getBoundary(newTier, _tiers);
      // Adjust min/max if out of bounds of the new tier boundary
      _currentMinXp = _currentMinXp.clamp(boundary.minXp, boundary.maxXp);
      _currentMaxXp = _currentMaxXp.clamp(boundary.minXp, boundary.maxXp);
      if (_currentMaxXp <= _currentMinXp) {
        _currentMinXp = boundary.minXp;
        _currentMaxXp = boundary.maxXp;
      }
      _minXpController.text = '$_currentMinXp';
      _maxXpController.text = '$_currentMaxXp';
      _errorMessage = null;
    });
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = KratosTierSystem.getColor(_selectedTier);
    final boundary = KratosTierSystem.getBoundary(_selectedTier, _tiers);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: KratosTheme.acidLime),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          KratosTierSystem.buildTierLeadingIcon(
                            _selectedTier,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'EDIT LEVEL DEFINITION',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Name Field
                  const Text(
                    'LEVEL NAME *',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Gold II',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tierColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tier Selection
                  const Text(
                    'TIER *',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  KratosDropdown<String>(
                    value: _tiers.any((t) => t.name == _selectedTier)
                        ? _selectedTier
                        : null,
                    hint: 'Select Tier',
                    isExpanded: true,
                    accentColor: tierColor,
                    leading: KratosTierSystem.buildTierLeadingIcon(
                      _selectedTier,
                      size: 14,
                    ),
                    items: _tiers.map((tier) {
                      final tColor = KratosTierSystem.getColor(tier.name);
                      return KratosDropdownItem<String>(
                        value: tier.name,
                        label: tier.name,
                        leading: KratosTierSystem.buildTierLeadingIcon(
                          tier.name,
                          size: 14,
                        ),
                        accentColor: tColor,
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) _onTierChanged(val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Category Selection
                  const Text(
                    'CATEGORY',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  KratosDropdown<String?>(
                    value: _selectedCategoryId,
                    hint: 'Select Category',
                    prefixIcon: Icons.folder_outlined,
                    isExpanded: true,
                    items: [
                      const KratosDropdownItem<String?>(
                        value: null,
                        label: 'No Category',
                      ),
                      ..._categories.map((cat) {
                        return KratosDropdownItem<String?>(
                          value: cat.id,
                          label: cat.name,
                          leading: const Icon(
                            Icons.folder_outlined,
                            color: KratosTheme.acidLime,
                            size: 15,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                  ),
                  const SizedBox(height: 14),

                  // Experience Range Specification with real Dual-Handle RangeSlider
                  _buildXpRangeSection(tierColor, boundary),
                  const SizedBox(height: 14),

                  // Description Field
                  const Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Enter progression requirements or description...',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tierColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: tierColor,
                        foregroundColor: const Color(0xFF0D0D0D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Level Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
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

  Widget _buildXpRangeSection(Color tierColor, TierBoundary boundary) {
    final span = _currentMaxXp - _currentMinXp;
    final isWithinBoundary =
        _currentMinXp >= boundary.minXp &&
        _currentMaxXp <= boundary.maxXp &&
        _currentMaxXp > _currentMinXp;

    final sliderMin = boundary.minXp.toDouble();
    final sliderMax = boundary.maxXp.toDouble();
    final clampedMin = _currentMinXp
        .clamp(boundary.minXp, boundary.maxXp)
        .toDouble();
    final clampedMax = _currentMaxXp
        .clamp(boundary.minXp, boundary.maxXp)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWithinBoundary
              ? tierColor.withValues(alpha: 0.25)
              : Colors.redAccent.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EXPERIENCE RANGE SPECIFICATION',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${boundary.tierName} Tier Boundary: ${_formatNumber(boundary.minXp)} — ${_formatNumber(boundary.maxXp)} XP',
                    style: TextStyle(
                      color: tierColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isWithinBoundary ? tierColor : Colors.redAccent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isWithinBoundary ? tierColor : Colors.redAccent)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  isWithinBoundary
                      ? '${_formatNumber(span)} XP Span'
                      : 'Out of Bounds',
                  style: TextStyle(
                    color: isWithinBoundary ? tierColor : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Selected Range Display
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_formatNumber(_currentMinXp)} XP',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: '  —  ',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '${_formatNumber(_currentMaxXp)} XP',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2-Handle Range Slider
          if (sliderMax > sliderMin)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: tierColor,
                inactiveTrackColor: Colors.white12,
                thumbColor: tierColor,
                overlayColor: tierColor.withValues(alpha: 0.2),
                valueIndicatorColor: const Color(0xFF161616),
                valueIndicatorTextStyle: TextStyle(
                  color: tierColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                trackHeight: 4,
                rangeThumbShape: const RoundRangeSliderThumbShape(
                  enabledThumbRadius: 8,
                ),
              ),
              child: RangeSlider(
                values: RangeValues(
                  clampedMin <= clampedMax ? clampedMin : sliderMin,
                  clampedMax >= clampedMin ? clampedMax : sliderMax,
                ),
                min: sliderMin,
                max: sliderMax,
                divisions: math.max(1, (boundary.maxXp - boundary.minXp) ~/ 50),
                labels: RangeLabels(
                  '${_formatNumber(_currentMinXp)} XP',
                  '${_formatNumber(_currentMaxXp)} XP',
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    _currentMinXp = values.start.round();
                    _currentMaxXp = values.end.round();
                    _minXpController.text = '$_currentMinXp';
                    _maxXpController.text = '$_currentMaxXp';
                    _errorMessage = null;
                  });
                },
              ),
            ),

          const SizedBox(height: 10),
          // Precision numeric inputs
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MINIMUM XP (ENTRY)',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _minXpController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null) {
                          setState(() {
                            _currentMinXp = parsed;
                          });
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tierColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MAXIMUM XP (PROMOTION)',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _maxXpController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        if (parsed != null) {
                          setState(() {
                            _currentMaxXp = parsed;
                          });
                        }
                      },
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tierColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Level Name cannot be empty.');
      return;
    }

    final minXp = int.tryParse(_minXpController.text.trim());
    final maxXp = int.tryParse(_maxXpController.text.trim());

    if (minXp == null || maxXp == null) {
      setState(() => _errorMessage = 'Please enter valid numeric XP values.');
      return;
    }

    final boundary = KratosTierSystem.getBoundary(_selectedTier, _tiers);

    if (minXp < boundary.minXp) {
      setState(
        () => _errorMessage =
            'Minimum XP ($minXp) cannot be lower than the $_selectedTier tier entry boundary (${boundary.minXp} XP).',
      );
      return;
    }

    if (maxXp > boundary.maxXp) {
      setState(
        () => _errorMessage =
            'Maximum XP ($maxXp) cannot exceed the $_selectedTier tier promotion boundary (${boundary.maxXp} XP).',
      );
      return;
    }

    if (maxXp <= minXp) {
      setState(
        () => _errorMessage =
            'Maximum XP ($maxXp) must be greater than Minimum XP ($minXp).',
      );
      return;
    }

    final selectedCategory = _selectedCategoryId != null
        ? _categories.where((c) => c.id == _selectedCategoryId).firstOrNull
        : null;

    final updated = widget.data.copyWith(
      name: name,
      description: _descController.text.trim(),
      tier: _selectedTier,
      category: selectedCategory,
      lowerXp: minXp,
      upperXp: maxXp,
      deltaXp: maxXp - minXp,
    );

    widget.onSave(updated);
    Navigator.of(context).pop();
  }
}
