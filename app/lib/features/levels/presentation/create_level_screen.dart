import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_tiers.dart';
import '../../../data/drift/app_database.dart';
import '../data/level_detail_repository.dart';
import 'level_detail_screen.dart';

/// Screen to create a new Level Definition with real Life Area Category integration,
/// Experience Engine boundary constraints, and live dual-handle range slider.
class CreateLevelScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final int? initialLevel;
  final String? initialTier;
  final String? initialCategoryId;

  const CreateLevelScreen({
    super.key,
    required this.database,
    required this.ownerId,
    this.initialLevel,
    this.initialTier,
    this.initialCategoryId,
  });

  @override
  State<CreateLevelScreen> createState() => _CreateLevelScreenState();
}

class _CreateLevelScreenState extends State<CreateLevelScreen> {
  late final LevelDetailRepository _repository;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _minXpController;
  late final TextEditingController _maxXpController;

  int _selectedLevel = 1;
  String _selectedTier = 'Bronze';
  String? _selectedCategoryId;
  List<Category> _categories = [];
  List<TierDefinition> _tiers = [];
  bool _loading = true;
  String? _errorMessage;

  int _currentMinXp = 1000;
  int _currentMaxXp = 3000;

  @override
  void initState() {
    super.initState();
    _repository = LevelDetailRepository(widget.database);
    _selectedLevel = widget.initialLevel ?? 1;
    _selectedTier = widget.initialTier ?? 'Bronze';
    _selectedCategoryId = widget.initialCategoryId;

    final boundary = KratosTierSystem.getBoundary(_selectedTier);
    _currentMinXp = boundary.minXp;
    _currentMaxXp = boundary.maxXp;

    _nameController = TextEditingController(
      text: '$_selectedTier ${RomanNumerals.toRoman(_selectedLevel)}',
    );
    _descController = TextEditingController();
    _minXpController = TextEditingController(text: '$_currentMinXp');
    _maxXpController = TextEditingController(text: '$_currentMaxXp');

    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _repository.getCategories(widget.ownerId);
    final tiers = await _repository.getTiers();

    if (widget.initialLevel == null) {
      final allLevels = await _repository.getAllLevelsWithDetails(
        widget.ownerId,
      );
      if (allLevels.isNotEmpty) {
        final maxLevel = allLevels.map((l) => l.level).fold(0, math.max);
        _selectedLevel = maxLevel + 1;
      }
    }

    if (mounted) {
      setState(() {
        _categories = categories;
        _tiers = tiers;
        if (_selectedCategoryId == null && _categories.isNotEmpty) {
          _selectedCategoryId = _categories.first.id;
        }

        // Re-evaluate boundary with loaded custom tiers
        final boundary = KratosTierSystem.getBoundary(_selectedTier, _tiers);
        _currentMinXp = boundary.minXp;
        _currentMaxXp = boundary.maxXp;
        _minXpController.text = '$_currentMinXp';
        _maxXpController.text = '$_currentMaxXp';

        if (_nameController.text.isEmpty ||
            _nameController.text.contains(RomanNumerals.toRoman(1))) {
          _nameController.text =
              '$_selectedTier ${RomanNumerals.toRoman(_selectedLevel)}';
        }

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
      _currentMinXp = boundary.minXp;
      _currentMaxXp = boundary.maxXp;
      _minXpController.text = '$_currentMinXp';
      _maxXpController.text = '$_currentMaxXp';
      _errorMessage = null;

      // Suggest clean updated level name
      _nameController.text =
          '$_selectedTier ${RomanNumerals.toRoman(_selectedLevel)}';
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

    return Scaffold(
      backgroundColor: KratosTheme.volcanic,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'NEW LEVEL DEFINITION',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 15,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: KratosTheme.acidLime),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Level Identity Banner
                  _buildIdentityHeader(tierColor),
                  const SizedBox(height: 20),

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
                    const SizedBox(height: 16),
                  ],

                  // 2. Tier Selection (Stage Level removed)
                  _buildTierSelector(tierColor),
                  const SizedBox(height: 16),

                  // 3. Level Name Field
                  _buildLabel('LEVEL NAME *'),
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
                  const SizedBox(height: 16),

                  // 4. Life Area Category Selector
                  _buildCategorySection(),
                  const SizedBox(height: 16),

                  // 5. Experience Range Specification with real Dual-Handle RangeSlider
                  _buildXpRangeSection(tierColor, boundary),
                  const SizedBox(height: 16),

                  // 6. Direction & Description Field
                  _buildLabel('DIRECTION & DESCRIPTION'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Define the mastery requirements and focus of this level...',
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
                  const SizedBox(height: 28),

                  // 7. Create Level Submit Action
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'CREATE LEVEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 14,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tierColor,
                      foregroundColor: const Color(0xFF0D0D0D),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildIdentityHeader(Color tierColor) {
    return ActiveGlassCard(
      active: false,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tierColor.withValues(alpha: 0.3)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tierColor.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: tierColor.withValues(alpha: 0.5)),
              ),
              child: Icon(
                KratosTierSystem.getIcon(_selectedTier),
                color: tierColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KratosTierSystem.buildTierPill(
                        _selectedTier,
                        customColor: tierColor,
                        fontSize: 10,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LEVEL $_selectedLevel',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : 'New Level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierSelector(Color tierColor) {
    final tierNames = _tiers.isNotEmpty
        ? _tiers.map((t) => t.name).toList()
        : ['Bronze', 'Silver', 'Gold', 'Crystal', 'Diamond', 'Mythic'];

    final selectedValue =
        tierNames.any((t) => t.toLowerCase() == _selectedTier.toLowerCase())
        ? tierNames.firstWhere(
            (t) => t.toLowerCase() == _selectedTier.toLowerCase(),
          )
        : tierNames.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('TIER *'),
        const SizedBox(height: 6),
        KratosDropdown<String>(
          value: selectedValue,
          hint: 'Select Tier',
          isExpanded: true,
          accentColor: tierColor,
          leading: KratosTierSystem.buildTierLeadingIcon(
            _selectedTier,
            size: 14,
          ),
          items: tierNames.map((t) {
            final tColor = KratosTierSystem.getColor(t);
            return KratosDropdownItem<String>(
              value: t,
              label: t,
              leading: KratosTierSystem.buildTierLeadingIcon(t, size: 14),
              accentColor: tColor,
            );
          }).toList(),
          onChanged: (tier) {
            if (tier != null) _onTierChanged(tier);
          },
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('LIFE AREA CATEGORY *'),
            InkWell(
              onTap: _openAddCategoryDialog,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 13, color: KratosTheme.acidLime),
                    SizedBox(width: 4),
                    Text(
                      'Add Category',
                      style: TextStyle(
                        color: KratosTheme.acidLime,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        KratosDropdown<String?>(
          value: _categories.any((c) => c.id == _selectedCategoryId)
              ? _selectedCategoryId
              : null,
          hint: 'Select a Life Area Category',
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
          onChanged: (catId) => setState(() => _selectedCategoryId = catId),
        ),
      ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWithinBoundary
              ? tierColor.withValues(alpha: 0.25)
              : Colors.redAccent.withValues(alpha: 0.5),
          width: 1.0,
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
                  _buildLabel('EXPERIENCE RANGE SPECIFICATION'),
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
          const SizedBox(height: 16),

          // Live Selected Range Display
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${_formatNumber(_currentMinXp)} XP',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(
                    text: '  —  ',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '${_formatNumber(_currentMaxXp)} XP',
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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

          const SizedBox(height: 12),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Future<void> _openAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<Category>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'New Life Area Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Category Name *',
            hintText: 'e.g. Health & Fitness, Business',
            labelStyle: TextStyle(color: Colors.white60),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final cat = await _repository.createLifeAreaCategory(
                ownerId: widget.ownerId,
                name: name,
              );
              if (ctx.mounted) Navigator.of(ctx).pop(cat);
            },
            style: FilledButton.styleFrom(
              backgroundColor: KratosTheme.acidLime,
              foregroundColor: Colors.black,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created != null && mounted) {
      final updatedList = await _repository.getCategories(widget.ownerId);
      setState(() {
        _categories = updatedList;
        _selectedCategoryId = created.id;
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Level Name is required.');
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

    setState(() => _errorMessage = null);

    try {
      final created = await _repository.createLevel(
        ownerId: widget.ownerId,
        level: _selectedLevel,
        name: name,
        tierName: _selectedTier,
        categoryId: _selectedCategoryId,
        description: _descController.text.trim(),
        minXp: minXp,
        maxXp: maxXp,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        KratosMaterialPageRoute<void>(
          builder: (_) => LevelDetailScreen(
            database: widget.database,
            ownerId: widget.ownerId,
            level: created.level,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }
}
