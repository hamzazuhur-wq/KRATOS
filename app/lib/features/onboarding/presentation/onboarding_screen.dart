// Wave 17: Onboarding Screen — Liquid Glass / Acid Lime aesthetic.
// Multi-step interactive flow to set up Life Areas, first Goal, and introduce game mechanics.

import 'package:flutter/material.dart';
import '../domain/onboarding_models.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function({
    required Set<String> selectedAreaIds,
    String? initialGoalTitle,
    int initialGoalXp,
  }) onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _goalController = TextEditingController(text: 'Establish Daily Consistency');

  int _currentPage = 0;
  final Set<String> _selectedAreaIds = {'la_health', 'la_career'};
  int _initialGoalXp = 500;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleFinish();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleFinish() async {
    setState(() => _isSubmitting = true);
    await widget.onComplete(
      selectedAreaIds: _selectedAreaIds,
      initialGoalTitle: _goalController.text.trim(),
      initialGoalXp: _initialGoalXp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Header Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(4, (index) {
                  final isActive = index <= _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFC6F135)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeStep(),
                  _buildLifeAreasStep(),
                  _buildFirstGoalStep(),
                  _buildGameRulesStep(),
                ],
              ),
            ),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back', style: TextStyle(color: Colors.white38)),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _nextPage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC6F135),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        _currentPage == 3
                            ? (_isSubmitting ? 'LAUNCHING...' : 'LAUNCH KRATOS')
                            : 'CONTINUE',
                        style: const TextStyle(
                          color: Color(0xFF0D0D0D),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/branding/kratos_logo.png',
            width: 84,
            height: 84,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 28),
          const Text(
            'WELCOME TO KRATOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The personal operating system engineered to gamify your life through immutable XP, per-area streaks, deep focus sessions, and compound mastery.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLifeAreasStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'CHOOSE YOUR LIFE AREAS',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Progression is per-area (Health, Career, etc). Select what matters most right now:',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 20),
        ...OnboardingDefaults.templates.map((template) {
          final isSelected = _selectedAreaIds.contains(template.id);
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  if (_selectedAreaIds.length > 1) {
                    _selectedAreaIds.remove(template.id);
                  }
                } else {
                  _selectedAreaIds.add(template.id);
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFC6F135).withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFC6F135).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFFC6F135) : Colors.white24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.description,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFirstGoalStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SET YOUR FIRST GOAL',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Goals anchor your tasks and activities with target XP rewards.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _goalController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Goal Title',
              labelStyle: const TextStyle(color: Color(0xFFC6F135)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'TARGET XP REWARD',
            style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [300, 500, 1000].map((xp) {
              final isChosen = _initialGoalXp == xp;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _initialGoalXp = xp),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isChosen
                          ? const Color(0xFFC6F135).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChosen ? const Color(0xFFC6F135) : Colors.white12,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$xp XP',
                      style: TextStyle(
                        color: isChosen ? const Color(0xFFC6F135) : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameRulesStep() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Text(
          'THE RULES OF THE SYSTEM',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Designed around behavioral psychology to keep you consistent:',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        SizedBox(height: 24),
        _RuleTile(
          icon: Icons.local_fire_department,
          iconColor: Color(0xFFFF9500),
          title: 'Daily Streaks per Life Area',
          description: 'Streaks track your daily consistency in each area independently. A 7-day streak unlocks a +20% XP bonus!',
        ),
        SizedBox(height: 12),
        _RuleTile(
          icon: Icons.ac_unit,
          iconColor: Color(0xFF00FFFF),
          title: '2 Free Freeze Tokens',
          description: 'Life gets busy. If you miss a day, an ice token auto-freezes your streak so you don’t lose your progress.',
        ),
        SizedBox(height: 12),
        _RuleTile(
          icon: Icons.receipt_long,
          iconColor: Color(0xFFC6F135),
          title: 'Immutable XP Ledger',
          description: 'All XP earned is forever auditable and append-only. No rewriting, no cheating.',
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _RuleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
