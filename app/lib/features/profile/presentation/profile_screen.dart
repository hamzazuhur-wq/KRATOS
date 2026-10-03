// KRATOS Profile & Account Screen.
// Identity center displaying user avatar, name, personal statement ("Who you are and who you want to be"),
// Leading XP Domain, Highest Level reached, Account Information, Change Password, and Logout.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_theme.dart';
import '../../../data/drift/app_database.dart';
import '../../auth/domain/auth_service.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';

class ProfileScreen extends StatefulWidget {
  final AppDatabase database;
  final String userId;
  final AuthService? authService;
  final VoidCallback? onSignOut;

  const ProfileScreen({
    super.key,
    required this.database,
    required this.userId,
    this.authService,
    this.onSignOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository;
  late final Stream<UserProfileData> _profileStream;

  @override
  void initState() {
    super.initState();
    _repository = ProfileRepository(
      database: widget.database,
      authService: widget.authService,
    );
    _profileStream = _repository.watchProfile(widget.userId);
  }

  void _openEditProfileDialog(UserProfileData profile) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _EditProfileDialog(
        profile: profile,
        repository: _repository,
        onSave: (newName, newCaption, newAvatarUrl) async {
          final messenger = ScaffoldMessenger.of(dialogContext);
          await _repository.updateProfile(
            userId: widget.userId,
            displayName: newName,
            caption: newCaption,
            avatarUrl: newAvatarUrl,
          );
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Profile updated successfully'),
                backgroundColor: Color(0xFF1E281E),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _openChangePasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ChangePasswordDialog(
        onChangePassword: (newPassword) async {
          final messenger = ScaffoldMessenger.of(dialogContext);
          await _repository.updatePassword(newPassword);
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully'),
                backgroundColor: Color(0xFF1E281E),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF111411),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFFF3B30), size: 20),
            SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out of KRATOS? Your local data will remain securely saved.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.2),
              foregroundColor: const Color(0xFFFF3B30),
              side: const BorderSide(color: Color(0xFFFF3B30)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _repository.signOut();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onSignOut?.call();
              }
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020302),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'PROFILE & ACCOUNT',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFFC6F135)),
            tooltip: 'Edit Profile',
            onPressed: () async {
              final currentProfile = await _repository.getProfile(widget.userId);
              if (mounted) _openEditProfileDialog(currentProfile);
            },
          ),
        ],
      ),
      body: StreamBuilder<UserProfileData>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFFF3B30), size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load profile: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFC6F135),
                ),
              ),
            );
          }

          final profile = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              // 1. Profile Header Card
              _ProfileHeaderCard(
                profile: profile,
                onEdit: () => _openEditProfileDialog(profile),
              ),
              const SizedBox(height: 16),

              // 2. Progression & XP Domain Summary Card
              _ProgressionIdentityCard(profile: profile),
              const SizedBox(height: 24),

              // 3. Account Information
              const _SectionLabel(title: 'ACCOUNT INFORMATION'),
              const SizedBox(height: 8),
              _AccountDetailsCard(profile: profile),
              const SizedBox(height: 24),

              // 4. Security & Account Actions
              const _SectionLabel(title: 'SECURITY & ACTIONS'),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.lock_reset_outlined,
                title: 'Change Password',
                subtitle: 'Update your Supabase authentication password.',
                onTap: _openChangePasswordDialog,
              ),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: 'End session and return to authentication screen.',
                isDestructive: true,
                onTap: _confirmSignOut,
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Profile Header Card
// -----------------------------------------------------------------------------

class _ProfileHeaderCard extends StatelessWidget {
  final UserProfileData profile;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({
    required this.profile,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    final hasImage = avatarUrl != null && avatarUrl.isNotEmpty;

    return ActiveGlassCard(
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Large Avatar with Glow and Edit Badge
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC6F135).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? (avatarUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(avatarUrl.split(',').last),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _FallbackAvatar(name: profile.displayName),
                              )
                            : Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => _FallbackAvatar(name: profile.displayName),
                              ))
                        : _FallbackAvatar(name: profile.displayName),
                  ),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF020302), width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF020302),
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // User Name
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Column(
                  children: [
                    Text(
                      profile.displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Caption / "Who you are and who you want to be"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0x0A0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : KratosTheme.lightBorderGlass,
                        ),
                      ),
                      child: Text(
                        (profile.caption != null && profile.caption!.isNotEmpty)
                            ? profile.caption!
                            : 'Who you are and who you want to be',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: (profile.caption != null && profile.caption!.isNotEmpty)
                              ? (isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime)
                              : (isDark ? Colors.white38 : KratosTheme.lightTextMuted),
                          fontSize: 12,
                          fontStyle: (profile.caption == null || profile.caption!.isEmpty)
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String name;

  const _FallbackAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'K';
    return Container(
      color: const Color(0xFF1E281E),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFC6F135),
          fontWeight: FontWeight.w900,
          fontSize: 32,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Progression Identity Card
// -----------------------------------------------------------------------------

class _ProgressionIdentityCard extends StatelessWidget {
  final UserProfileData profile;

  const _ProgressionIdentityCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0D0F0D).withValues(alpha: 0.9)
            : const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.25 : 0.4),
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Primary XP Domain
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.stars, color: accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'PRIMARY XP DOMAIN',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.primaryXpDomain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 36,
            width: 1,
            color: isDark ? Colors.white12 : const Color(0x1F0F172A),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Highest Level Reached
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'HIGHEST LEVEL',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.highestLevel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
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

// -----------------------------------------------------------------------------
// Account Details Card
// -----------------------------------------------------------------------------

class _AccountDetailsCard extends StatelessWidget {
  final UserProfileData profile;

  const _AccountDetailsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white10 : const Color(0x1F0F172A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : KratosTheme.lightBorderGlass,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'Email',
            value: profile.email ?? 'Not provided',
            icon: Icons.email_outlined,
          ),
          Divider(color: dividerColor, height: 16),
          _DetailRow(
            label: 'Account Status',
            value: 'Active • Supabase / Offline',
            icon: Icons.verified_user_outlined,
            valueColor: isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime,
          ),
          Divider(color: dividerColor, height: 16),
          _DetailRow(
            label: 'User ID',
            value: profile.userId.value,
            icon: Icons.fingerprint,
            isMonospace: true,
          ),
          Divider(color: dividerColor, height: 16),
          _DetailRow(
            label: 'Member Since',
            value: '${profile.createdAt.year}-${profile.createdAt.month.toString().padLeft(2, '0')}-${profile.createdAt.day.toString().padLeft(2, '0')}',
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool isMonospace;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.white38 : KratosTheme.lightTextMuted, size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white70 : KratosTheme.lightTextPrimary),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? const Color(0xFFFF3B30)
        : (isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime);

    return Container(
      decoration: BoxDecoration(
        color: isDestructive
            ? const Color(0xFFFF3B30).withValues(alpha: isDark ? 0.05 : 0.08)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xF2FFFFFF)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDestructive
              ? const Color(0xFFFF3B30).withValues(alpha: isDark ? 0.3 : 0.4)
              : (isDark ? Colors.white10 : KratosTheme.lightBorderGlass),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDestructive
                              ? const Color(0xFFFF3B30)
                              : (isDark ? Colors.white : KratosTheme.lightTextPrimary),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDestructive
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.5)
                      : (isDark ? Colors.white30 : KratosTheme.lightTextMuted),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Dialogs: Edit Profile & Change Password
// -----------------------------------------------------------------------------

class _EditProfileDialog extends StatefulWidget {
  final UserProfileData profile;
  final ProfileRepository repository;
  final Future<void> Function(String name, String? caption, String? avatarUrl) onSave;

  const _EditProfileDialog({
    required this.profile,
    required this.repository,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _captionController;
  late final TextEditingController _avatarUrlController;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _captionController = TextEditingController(text: widget.profile.caption ?? '');
    _avatarUrlController = TextEditingController(text: widget.profile.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _captionController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final caption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : null;

    final avatar = _avatarUrlController.text.trim().isNotEmpty
        ? _avatarUrlController.text.trim()
        : null;

    setState(() => _saving = true);
    try {
      await widget.onSave(name, caption, avatar);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111411),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text(
        'Edit Profile',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NAME *',
              style: TextStyle(color: Color(0xFFC6F135), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'WHO YOU ARE AND WHO YOU WANT TO BE',
              style: TextStyle(color: Color(0xFFC6F135), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _captionController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Who you are and who you want to be',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'AVATAR IMAGE',
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _uploadingImage || _saving
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 512,
                            maxHeight: 512,
                            imageQuality: 85,
                          );
                          if (picked != null) {
                            setState(() => _uploadingImage = true);
                            try {
                              final bytes = await picked.readAsBytes();
                              final ext = picked.name.split('.').last.toLowerCase();
                              final uploadedUrl = await widget.repository.uploadAvatar(
                                userId: widget.profile.userId.value,
                                bytes: bytes,
                                fileExt: ext.isEmpty ? 'png' : ext,
                              );
                              if (mounted) {
                                setState(() {
                                  _avatarUrlController.text = uploadedUrl;
                                  _uploadingImage = false;
                                });
                              }
                            } catch (_) {
                              if (mounted) setState(() => _uploadingImage = false);
                            }
                          }
                        },
                  icon: _uploadingImage
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC6F135)),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 14, color: Color(0xFFC6F135)),
                  label: Text(
                    _uploadingImage ? 'Uploading...' : 'Pick from Device',
                    style: const TextStyle(color: Color(0xFFC6F135), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _avatarUrlController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://... or pick from gallery above',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC6F135),
            foregroundColor: const Color(0xFF020302),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final Future<void> Function(String newPassword) onChangePassword;

  const _ChangePasswordDialog({required this.onChangePassword});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.isEmpty) {
      setState(() => _error = 'Password cannot be empty');
      return;
    }

    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onChangePassword(pass);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111411),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text(
        'Change Password',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12),
                ),
              ),
            const Text(
              'NEW PASSWORD *',
              style: TextStyle(color: Color(0xFFC6F135), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter new password',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'CONFIRM NEW PASSWORD *',
              style: TextStyle(color: Color(0xFFC6F135), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC6F135),
            foregroundColor: const Color(0xFF020302),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Update', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
