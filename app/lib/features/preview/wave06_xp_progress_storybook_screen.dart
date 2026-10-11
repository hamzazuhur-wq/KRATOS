import 'package:flutter/material.dart';

import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../analytics/data/xp_progress_repository.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/domain/xp_progress_models.dart';
import '../analytics/presentation/widgets/analytics_xp_progress_card.dart';

/// Wave 06: Dedicated XP Progress & Life Area Progression Storybook / Preview Screen.
///
/// Provides interactive preview covering:
/// 1. Dark Mode — Populated (Reference target: Level IV — Crystal)
/// 2. Light Mode — Populated
/// 3. Dark Mode — All Life Areas (Portfolio overview semantics)
/// 4. Light Mode — All Life Areas
/// 5. High Tier — Diamond V
/// 6. Empty State — Brand new domain (Wood I, 0 XP)
/// 7. Loading Skeleton
/// 8. Error State (with user retry flow)
/// 9. Responsive Viewports: Desktop (Full), Tablet (768px), Mobile (390px)
class Wave06XpProgressStorybookScreen extends StatefulWidget {
  const Wave06XpProgressStorybookScreen({super.key});

  @override
  State<Wave06XpProgressStorybookScreen> createState() =>
      _Wave06XpProgressStorybookScreenState();
}

enum _Wave06Preset {
  populatedArea,
  allLifeAreas,
  highTierDiamond,
  emptyArea,
  loadingSkeleton,
  errorState,
}

enum _ViewportPreset {
  desktop,
  tablet,
  mobile,
}

class _Wave06XpProgressStorybookScreenState
    extends State<Wave06XpProgressStorybookScreen> {
  _Wave06Preset _selectedPreset = _Wave06Preset.populatedArea;
  _ViewportPreset _viewport = _ViewportPreset.desktop;
  int _renderKey = 0;

  XpProgressRepository _buildRepository() {
    return switch (_selectedPreset) {
      _Wave06Preset.populatedArea => const MockXpProgressRepository(),
      _Wave06Preset.allLifeAreas => const MockXpProgressRepository(),
      _Wave06Preset.highTierDiamond => const MockXpProgressRepository(
          overrideTier: 'Diamond',
          overrideLevel: 5,
          overrideRoman: 'V',
          overrideProgress: 94.6,
        ),
      _Wave06Preset.emptyArea => const MockXpProgressRepository(
          isEmpty: true,
        ),
      _Wave06Preset.loadingSkeleton => const _IndefiniteLoadingRepository(),
      _Wave06Preset.errorState => const MockXpProgressRepository(
          shouldFail: true,
        ),
    };
  }

  String? _initialLifeAreaId() {
    return switch (_selectedPreset) {
      _Wave06Preset.allLifeAreas => null,
      _Wave06Preset.populatedArea => 'la_prof',
      _Wave06Preset.highTierDiamond => 'la_prof',
      _Wave06Preset.emptyArea => 'la_new',
      _Wave06Preset.loadingSkeleton => 'la_prof',
      _Wave06Preset.errorState => 'la_prof',
    };
  }

  @override
  Widget build(BuildContext context) {
    final themeController = KratosThemeController.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double? containerWidth;
    switch (_viewport) {
      case _ViewportPreset.desktop:
        containerWidth = null; // Fluid max width
        break;
      case _ViewportPreset.tablet:
        containerWidth = 768;
        break;
      case _ViewportPreset.mobile:
        containerWidth = 390;
        break;
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF040604) : const Color(0xFFF2F4F2),
      body: SafeArea(
        child: Column(
          children: [
            // ── Storybook Top Control Toolbar ────────────────────────────────
            _buildToolbar(context, isDark, themeController),

            // ── Interactive Viewport Canvas ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: Container(
                    width: containerWidth,
                    constraints: containerWidth == null
                        ? const BoxConstraints(maxWidth: 1280)
                        : null,
                    decoration: containerWidth != null
                        ? BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black26,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    padding: containerWidth != null
                        ? const EdgeInsets.all(12)
                        : EdgeInsets.zero,
                    child: KeyedSubtree(
                      key: ValueKey('xp_progress_$_selectedPreset$_renderKey'),
                      child: AnalyticsXpProgressCard(
                        key: ValueKey(
                            'card_${_selectedPreset.name}_$_renderKey'),
                        initialLifeAreaId: _initialLifeAreaId(),
                        startWithAllAreas:
                            _selectedPreset == _Wave06Preset.allLifeAreas,
                        initialPeriod: AnalyticsPeriod.month,
                        repository: _buildRepository(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    bool isDark,
    KratosThemeController themeController,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101410) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0x1F0F172A),
          ),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: KratosTheme.acidLime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'WAVE 06: XP PROGRESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color:
                      isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // Preset Dropdown
          DropdownButton<_Wave06Preset>(
            value: _selectedPreset,
            dropdownColor:
                isDark ? const Color(0xFF181D18) : Colors.white,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: _Wave06Preset.populatedArea,
                child: Text('Level IV — Crystal (Reference)'),
              ),
              DropdownMenuItem(
                value: _Wave06Preset.allLifeAreas,
                child: Text('All Life Areas (Portfolio Semantics)'),
              ),
              DropdownMenuItem(
                value: _Wave06Preset.highTierDiamond,
                child: Text('Level V — Diamond (High Tier)'),
              ),
              DropdownMenuItem(
                value: _Wave06Preset.emptyArea,
                child: Text('Empty Domain (Wood I, 0 XP)'),
              ),
              DropdownMenuItem(
                value: _Wave06Preset.loadingSkeleton,
                child: Text('Loading Skeleton'),
              ),
              DropdownMenuItem(
                value: _Wave06Preset.errorState,
                child: Text('Error State (Retry flow)'),
              ),
            ],
            onChanged: (preset) {
              if (preset != null) {
                setState(() {
                  _selectedPreset = preset;
                  _renderKey++;
                });
              }
            },
          ),

          // Viewport Selector
          DropdownButton<_ViewportPreset>(
            value: _viewport,
            dropdownColor:
                isDark ? const Color(0xFF181D18) : Colors.white,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: _ViewportPreset.desktop,
                child: Text('Desktop (Fluid)'),
              ),
              DropdownMenuItem(
                value: _ViewportPreset.tablet,
                child: Text('Tablet (768px)'),
              ),
              DropdownMenuItem(
                value: _ViewportPreset.mobile,
                child: Text('Mobile (390px)'),
              ),
            ],
            onChanged: (vp) {
              if (vp != null) setState(() => _viewport = vp);
            },
          ),

          // Theme Toggle Button
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () {
              themeController.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),

          // Quick Refresh
          IconButton(
            tooltip: 'Reload / Refresh Preset',
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            onPressed: () {
              setState(() => _renderKey++);
            },
          ),
        ],
      ),
    );
  }
}

/// Simulated indefinite loading repository
class _IndefiniteLoadingRepository implements XpProgressRepository {
  const _IndefiniteLoadingRepository();

  @override
  Future<List<({String id, String name})>> listLifeAreas(String ownerId) {
    return Future.value(const [
      (id: 'la_prof', name: 'Professional'),
    ]);
  }

  @override
  Future<XpProgressData> load({
    required String ownerId,
    required AnalyticsPeriod period,
    String? lifeAreaId,
  }) {
    // Deliberately never resolves to display skeleton state
    return Future<XpProgressData>.delayed(const Duration(hours: 1));
  }
}
