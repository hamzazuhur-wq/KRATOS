import 'package:flutter/material.dart';

import '../../app/kratos_dropdown.dart';
import '../../app/kratos_motion.dart';
import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../../app/kratos_visuals.dart';

/// Wave 14 Storybook / Widget Previews Screen:
/// Demonstrates the complete visual system for Creation & Editing surfaces,
/// shared active surfaces, dropdowns, selectors, validation states,
/// action buttons, and confirmation dialogs in both Dark Mode (master) and Light Mode.
class Wave14CreationEditingStorybookScreen extends StatefulWidget {
  const Wave14CreationEditingStorybookScreen({super.key});

  @override
  State<Wave14CreationEditingStorybookScreen> createState() =>
      _Wave14CreationEditingStorybookScreenState();
}

class _Wave14CreationEditingStorybookScreenState
    extends State<Wave14CreationEditingStorybookScreen> {
  // Form input controllers
  final _titleController =
      TextEditingController(text: 'Build Master Creation System');
  final _descController = TextEditingController(
      text: 'Unified Liquid Glass creation and editing surfaces across all KRATOS modules.');
  final _errorController = TextEditingController(text: 'Invalid entry');
  final _formKey = GlobalKey<FormState>();

  // State selections
  String? _selectedCategory = 'Engineering';
  String? _selectedPriority = 'P1 - High';
  final Set<String> _selectedSkills = {'Flutter', 'Architecture'};
  bool _switchValue = true;
  bool _isLoading = false;

  final List<String> _categories = [
    'Engineering',
    'Design',
    'Health',
    'Finance',
    'Mindset',
  ];

  final List<String> _skills = [
    'Flutter',
    'Architecture',
    'UI/UX',
    'Database',
    'System Design',
    'Security',
  ];

  @override
  void initState() {
    super.initState();
    final theme = Uri.base.queryParameters['theme'];
    if (theme == 'light' || theme == 'dark') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        KratosThemeController.instance.setThemeMode(
          theme == 'light' ? ThemeMode.light : ThemeMode.dark,
        );
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _triggerConfirmationDialog(bool isDark, Color lime, Color textColor, Color mutedColor) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: KratosModalEntrance(
            child: KratosGlassCard(
              variant: KratosSurfaceVariant.elevated,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'DELETE ENTITY',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Are you sure you want to permanently delete this item? This action will soft-delete all associated links and cannot be undone.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: mutedColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: mutedColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      KratosPressable(
                        onTap: () {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Entity successfully deleted',
                                style: TextStyle(fontFamily: 'IBM Plex Mono'),
                              ),
                              backgroundColor: isDark
                                  ? const Color(0xFF141614)
                                  : Colors.white,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'CONFIRM DELETE',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
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
  }

  void _triggerModalSheet(bool isDark, Color lime, Color textColor, Color mutedColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
            maxWidth: 600,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: KratosModalEntrance(
            child: KratosGlassCard(
              variant: KratosSurfaceVariant.elevated,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'QUICK CREATE TASK',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: mutedColor, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TASK NAME',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter task description...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  KratosPressable(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CREATE TASK',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF888E83) : KratosTheme.lightTextSecondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020302) : const Color(0xFFF7F6F2),
      appBar: AppBar(
        title: Text(
          'WAVE 14 · CREATION & EDITING SYSTEM',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Row(
            children: [
              Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                size: 16,
                color: lime,
              ),
              const SizedBox(width: 6),
              Text(
                isDark ? 'DARK' : 'LIGHT',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: lime,
                ),
              ),
              Switch(
                value: !isDark,
                activeThumbColor: lime,
                onChanged: (val) {
                  KratosThemeController.instance.setThemeMode(
                    val ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // System Overview Header
              KratosGlassCard(
                variant: KratosSurfaceVariant.elevated,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: lime.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.tune_outlined, color: lime, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNIFIED ACTIVE EDITING SURFACES',
                            style: TextStyle(
                              fontFamily: 'Space Grotesk',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: textColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Every creation, editing, selector, dropdown, modal sheet, and confirmation dialogue across KRATOS uses this cohesive material geometry.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Shared Form System (Text, Multiline, Validation)
              _buildSectionHeader('01 / INPUT FIELDS & VALIDATION STATES', lime),
              const SizedBox(height: 12),
              KratosGlassCard(
                variant: KratosSurfaceVariant.elevated,
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Normal Active Field
                      Text(
                        'TITLE (FOCUSED / ACTIVE STATE)',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: textColor,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter title...',
                          hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: lime, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Multiline Field
                      Text(
                        'DESCRIPTION (MULTILINE)',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: textColor,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Provide deep contextual notes...',
                          hintStyle: TextStyle(color: mutedColor.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: lime, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Validation Error State
                      Text(
                        'VALIDATION FEEDBACK (ERROR STATE)',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _errorController,
                        autovalidateMode: AutovalidateMode.always,
                        validator: (value) => 'Name exceeds maximum character budget (60 chars)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: textColor,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                          errorStyle: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 11,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Disabled Field
                      Text(
                        'IMMUTABLE HLC IDENTIFIER (DISABLED STATE)',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: '2026-10-06T09:30:00.000Z-node01',
                        enabled: false,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mutedColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.black.withValues(alpha: 0.02),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section 2: Dropdowns & Selectors
              _buildSectionHeader('02 / DROPDOWNS & ENTITY SELECTORS', lime),
              const SizedBox(height: 12),
              KratosGlassCard(
                variant: KratosSurfaceVariant.elevated,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // KratosDropdownFormField
                    Text(
                      'CATEGORY SELECTOR (DROPDOWN)',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    KratosDropdownFormField<String>(
                      hint: 'Select category',
                      initialValue: _selectedCategory,
                      items: _categories.map((c) {
                        return KratosDropdownItem<String>(
                          value: c,
                          label: c,
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                    const SizedBox(height: 20),

                    // Choice Chips Selector
                    Text(
                      'PRIORITY SELECTOR (SINGLE-SELECT CHIPS)',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['P0 - Critical', 'P1 - High', 'P2 - Medium', 'P3 - Low'].map((p) {
                        final isSelected = _selectedPriority == p;
                        return ChoiceChip(
                          label: Text(
                            p,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0D0D0D) : Colors.white)
                                  : mutedColor,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedPriority = p);
                          },
                          selectedColor: lime,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: isSelected
                                ? lime
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Multi-select Skills
                    Text(
                      'LINKED SKILLS (MULTI-SELECT CHIPS)',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _skills.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(
                            skill,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? lime : mutedColor,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                          selectedColor: lime.withValues(alpha: 0.16),
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04),
                          side: BorderSide(
                            color: isSelected
                                ? lime.withValues(alpha: 0.6)
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _switchValue ? lime.withValues(alpha: 0.4) : (isDark ? Colors.white10 : Colors.black12),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _switchValue,
                        activeThumbColor: lime,
                        onChanged: (val) => setState(() => _switchValue = val),
                        title: Text(
                          'Notify Linked Sub-Goals on Completion',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Action Buttons & Saving States
              _buildSectionHeader('03 / ACTION BUTTONS & ASYNC LIFECYCLE', lime),
              const SizedBox(height: 12),
              KratosGlassCard(
                variant: KratosSurfaceVariant.elevated,
                padding: const EdgeInsets.all(22),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Primary Action Button
                    KratosPressable(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              await Future.delayed(const Duration(seconds: 1));
                              if (mounted) setState(() => _isLoading = false);
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: lime.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLoading)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Text(
                              _isLoading ? 'SAVING...' : 'SAVE CHANGES',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Secondary Action Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {},
                      child: Text(
                        'DISCARD',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 11,
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Destructive Action Trigger
                    KratosPressable(
                      onTap: () => _triggerConfirmationDialog(isDark, lime, textColor, mutedColor),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'OPEN DELETE CONFIRMATION',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Sheet Trigger
                    KratosPressable(
                      onTap: () => _triggerModalSheet(isDark, lime, textColor, mutedColor),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black26),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vertical_align_top, color: textColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'OPEN CREATION SHEET',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color lime) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: lime,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
