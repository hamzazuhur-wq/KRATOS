// Wave 21: Share Goal Dialog — Liquid Glass aesthetic.
// Allows inviting an accountability partner or coach with scoped permissions.

import 'package:flutter/material.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../domain/collaboration_models.dart';

class ShareGoalDialog extends StatefulWidget {
  final String goalTitle;
  final void Function(String partnerEmail, PartnerRole role) onShare;

  const ShareGoalDialog({
    super.key,
    required this.goalTitle,
    required this.onShare,
  });

  @override
  State<ShareGoalDialog> createState() => _ShareGoalDialogState();
}

class _ShareGoalDialogState extends State<ShareGoalDialog> {
  final _emailController = TextEditingController();
  PartnerRole _selectedRole = PartnerRole.accountabilityPartner;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: lime.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.people_alt_outlined, color: lime, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ACCOUNTABILITY PARTNER',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: lime,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedColor, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Share "${widget.goalTitle}" with a partner or coach to stay committed.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Partner email or ID',
                    hintStyle: TextStyle(color: mutedColor, fontSize: 13),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: lime, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SELECT ROLE',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: PartnerRole.values.map((role) {
                    final isChosen = _selectedRole == role;
                    final label = switch (role) {
                      PartnerRole.viewer => 'Viewer',
                      PartnerRole.accountabilityPartner => 'Partner',
                      PartnerRole.coach => 'Coach',
                    };

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = role),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isChosen
                                ? lime.withValues(alpha: 0.15)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isChosen
                                  ? lime
                                  : (isDark ? Colors.white12 : Colors.black12),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: isChosen ? lime : mutedColor,
                              fontSize: 11,
                              fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KratosPressable(
                      onTap: () {
                        final email = _emailController.text.trim();
                        if (email.isNotEmpty) {
                          widget.onShare(email, _selectedRole);
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'SEND INVITE',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: isDark ? const Color(0xFF020302) : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
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
    );
  }
}
