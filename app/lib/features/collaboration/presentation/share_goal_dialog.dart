// Wave 21: Share Goal Dialog — Liquid Glass aesthetic.
// Allows inviting an accountability partner or coach with scoped permissions.

import 'package:flutter/material.dart';
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
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: Row(
        children: [
          const Icon(Icons.people_alt_outlined, color: Color(0xFFC6F135), size: 22),
          const SizedBox(width: 8),
          const Text(
            'ACCOUNTABILITY PARTNER',
            style: TextStyle(
              color: Color(0xFFC6F135),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share "${widget.goalTitle}" with a partner or coach to stay committed.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Partner email or ID',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Role:', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          ? const Color(0xFFC6F135).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isChosen ? const Color(0xFFC6F135) : Colors.white12,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isChosen ? const Color(0xFFC6F135) : Colors.white60,
                        fontSize: 12,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () {
            final email = _emailController.text.trim();
            if (email.isNotEmpty) {
              widget.onShare(email, _selectedRole);
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC6F135),
            foregroundColor: const Color(0xFF0D0D0D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Send Invite', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
