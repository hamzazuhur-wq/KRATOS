// KRATOS Profile & Account Screen.
// Identity center displaying user avatar, name, personal statement ("Who you are and who you want to be"),
// Leading XP Domain, Highest Level reached, Account Information, Change Password, and Logout.
//
// Wave 13: visual layer lives in `profile_components.dart`. This file keeps the
// existing behavior (streams, repository calls, dialogs, sign-out flow) intact.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/kratos_motion.dart';
import '../../../data/drift/app_database.dart';
import '../../auth/domain/auth_service.dart';
import '../data/profile_repository.dart';
import '../domain/profile_models.dart';
import 'profile_components.dart';

class ProfileScreen extends StatefulWidget {
  final AppDatabase database;
  final String userId;
  final AuthService? authService;
  final VoidCallback? onSignOut;

  /// Preview-only hook (`edit` | `password` | `signout`) used by the Wave 13
  /// web preview route to render nested dialogs. Null in production.
  final String? previewDialog;

  const ProfileScreen({
    super.key,
    required this.database,
    required this.userId,
    this.authService,
    this.onSignOut,
    this.previewDialog,
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

    final preview = widget.previewDialog;
    if (preview != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        switch (preview) {
          case 'edit':
            _openEditProfileDialog(await _repository.getProfile(widget.userId));
          case 'password':
            _openChangePasswordDialog();
          case 'signout':
            _confirmSignOut();
        }
      });
    }
  }

  void _openEditProfileDialog(UserProfileData profile) {
    showProfileDialog<void>(
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
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _openChangePasswordDialog() {
    showProfileDialog<void>(
      context: context,
      builder: (dialogContext) => _ChangePasswordDialog(
        onChangePassword: (newPassword) async {
          final messenger = ScaffoldMessenger.of(dialogContext);
          await _repository.updatePassword(newPassword);
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Password changed successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmSignOut() {
    showProfileDialog<void>(
      context: context,
      builder: (dialogContext) => ProfileDialogSurface(
        eyebrow: 'Account / session',
        title: 'Sign Out',
        icon: Icons.logout,
        destructive: true,
        maxWidth: 420,
        actions: [
          ProfileButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ProfileButton(
            label: 'Sign Out',
            kind: ProfileButtonKind.danger,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _repository.signOut();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onSignOut?.call();
              }
            },
          ),
        ],
        child: const ProfileSignOutBody(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ink.secondary),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'PROFILE & ACCOUNT',
          style: ink.eyebrow(color: ink.accent).copyWith(fontSize: 12, letterSpacing: 2.2),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: ink.accent),
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
            return ProfileErrorState(message: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const ProfileLoadingState();
          }

          final profile = snapshot.data!;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  // 1. Identity (strongest anchor)
                  KratosPageEntrance(
                    child: ProfileHeaderCard(
                      profile: profile,
                      onEdit: () => _openEditProfileDialog(profile),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Progression summary
                  KratosPageEntrance(
                    delay: const Duration(milliseconds: 60),
                    child: ProfileProgressionCard(profile: profile),
                  ),
                  const SizedBox(height: 28),

                  // 3 + 4. Account information and actions
                  KratosPageEntrance(
                    delay: const Duration(milliseconds: 120),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final account = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ProfileSectionHeader(
                              eyebrow: 'Account',
                              title: 'Account Information',
                            ),
                            ProfileAccountCard(profile: profile),
                          ],
                        );
                        final actions = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ProfileSectionHeader(
                              eyebrow: 'Security',
                              title: 'Security & Actions',
                            ),
                            ProfileActionTile(
                              icon: Icons.lock_reset_outlined,
                              title: 'Change Password',
                              subtitle: 'Update your Supabase authentication password.',
                              onTap: _openChangePasswordDialog,
                            ),
                            const SizedBox(height: 10),
                            ProfileActionTile(
                              icon: Icons.logout,
                              title: 'Sign Out',
                              subtitle: 'End session and return to authentication screen.',
                              isDestructive: true,
                              onTap: _confirmSignOut,
                            ),
                          ],
                        );
                        if (c.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: account),
                              const SizedBox(width: 20),
                              Expanded(flex: 9, child: actions),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            account,
                            const SizedBox(height: 24),
                            actions,
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
  String? _nameError;
  String? _saveError;

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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }

    final caption = _captionController.text.trim().isNotEmpty
        ? _captionController.text.trim()
        : null;

    final avatar = _avatarUrlController.text.trim().isNotEmpty
        ? _avatarUrlController.text.trim()
        : null;

    setState(() {
      _saving = true;
      _nameError = null;
      _saveError = null;
    });
    try {
      await widget.onSave(name, caption, avatar);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save your profile. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProfileDialogSurface(
      eyebrow: 'Identity / edit',
      title: 'Edit Profile',
      icon: Icons.person_outline,
      actions: [
        ProfileButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        ProfileButton(
          label: 'Save',
          kind: ProfileButtonKind.primary,
          loading: _saving,
          loadingLabel: 'Saving',
          onPressed: _submit,
        ),
      ],
      child: ProfileEditFormBody(
        previewName: widget.profile.displayName,
        nameController: _nameController,
        captionController: _captionController,
        avatarController: _avatarUrlController,
        nameError: _nameError,
        saveError: _saveError,
        uploading: _uploadingImage,
        saving: _saving,
        onPickAvatar: _pickAvatar,
      ),
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
    return ProfileDialogSurface(
      eyebrow: 'Account / security',
      title: 'Change Password',
      icon: Icons.lock_reset_outlined,
      actions: [
        ProfileButton(
          label: 'Cancel',
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        ProfileButton(
          label: 'Update',
          kind: ProfileButtonKind.primary,
          loading: _saving,
          loadingLabel: 'Updating',
          onPressed: _submit,
        ),
      ],
      child: ProfilePasswordFormBody(
        newController: _newPasswordController,
        confirmController: _confirmPasswordController,
        error: _error,
        saving: _saving,
      ),
    );
  }
}
