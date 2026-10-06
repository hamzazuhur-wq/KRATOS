import 'package:flutter/material.dart';

import '../../app/kratos_theme_controller.dart';
import '../../domain/ids.dart';
import '../profile/domain/profile_models.dart';
import '../profile/presentation/profile_components.dart';

/// Wave 13 Storybook / Widget Previews — Profile + Account + Identity.
///
/// Renders every EXISTING Profile / Account / Identity component and state in
/// the active theme (Dark master / Light translation). Toggle the theme with the
/// switch in the app bar, or open `?preview=wave13&theme=light`.
class Wave13ProfileStorybookScreen extends StatefulWidget {
  const Wave13ProfileStorybookScreen({super.key});

  @override
  State<Wave13ProfileStorybookScreen> createState() =>
      _Wave13ProfileStorybookScreenState();
}

// 1x1 PNG used to demonstrate the "image" avatar state without network access.
const _samplePng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _Wave13ProfileStorybookScreenState
    extends State<Wave13ProfileStorybookScreen> {
  final _name = TextEditingController(text: 'Hamza Zuhur');
  final _nameEmpty = TextEditingController();
  final _caption = TextEditingController(text: 'Building a calmer, louder life.');
  final _avatar = TextEditingController();
  final _avatarUrl = TextEditingController(text: 'https://example.com/avatar.png');
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  final _pwFilled1 = TextEditingController(text: 'secret1');
  final _pwFilled2 = TextEditingController(text: 'secret2');

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
    for (final c in [
      _name, _nameEmpty, _caption, _avatar, _avatarUrl, _pw1, _pw2,
      _pwFilled1, _pwFilled2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  UserProfileData _profile({
    String name = 'Hamza Zuhur',
    String? caption = 'Building a calmer, louder life.',
    String? avatar,
    String? email = 'hamza@kratos.app',
  }) =>
      UserProfileData(
        userId: Id('3f8a1c52-7b9e-4d21-a6f0-91c4e2d7b085'),
        displayName: name,
        caption: caption,
        avatarUrl: avatar,
        email: email,
        timezone: 'UTC',
        createdAt: DateTime(2026, 3, 14),
        primaryXpDomain: 'Health & Vitality',
        highestLevel: 'Gold Level 4',
        totalXp: 4820,
      );

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final isDark = ink.isDark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('WAVE 13 · PROFILE + ACCOUNT + IDENTITY',
            style: ink.eyebrow(color: ink.accent).copyWith(fontSize: 11, letterSpacing: 1.8)),
        actions: [
          Center(child: Text(isDark ? 'DARK' : 'LIGHT', style: ink.eyebrow())),
          Switch(
            value: isDark,
            onChanged: (_) => KratosThemeController.instance.toggle(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _group('01 / Profile header', [
                    _spec('Header · default', 640, ProfileHeaderCard(profile: _profile(), onEdit: () {})),
                    _spec('Header · no caption (empty caption)', 640,
                        ProfileHeaderCard(profile: _profile(caption: null), onEdit: () {})),
                    _spec('Header · narrow / long name', 340,
                        ProfileHeaderCard(
                          profile: _profile(
                            name: 'Alexandria Montgomery-Featherstonehaugh III',
                            caption:
                                'An exceptionally long personal statement that must wrap and truncate gracefully inside the identity header.',
                          ),
                          onEdit: () {},
                        )),
                    _spec('Header · uploading avatar', 640,
                        ProfileHeaderCard(profile: _profile(), onEdit: () {}, uploading: true)),
                  ]),
                  _group('02 / Avatar states', [
                    _spec('Initials', 130, ProfileAvatar(name: 'Hamza', size: 96)),
                    _spec('Image', 130, ProfileAvatar(name: 'Hamza', avatarUrl: _samplePng, size: 96)),
                    _spec('Image error → initials', 130,
                        ProfileAvatar(name: 'Hamza', avatarUrl: 'https://invalid.local/x.png', size: 96)),
                    _spec('Editable (badge)', 130, ProfileAvatar(name: 'Hamza', size: 96, onEdit: () {})),
                    _spec('Uploading', 130, ProfileAvatar(name: 'Hamza', size: 96, uploading: true)),
                    _spec('Compact (dialog)', 90, ProfileAvatar(name: 'Hamza', size: 64)),
                  ]),
                  _group('03 / Progression + Account information', [
                    _spec('Progression summary', 520, ProfileProgressionCard(profile: _profile())),
                    _spec('Account information', 520, ProfileAccountCard(profile: _profile())),
                    _spec('Account · long email, narrow', 340,
                        ProfileAccountCard(
                          profile: _profile(
                            email: 'a.very.long.email.address.for.testing.wrapping@subdomain.example-company.com',
                          ),
                        )),
                  ]),
                  _group('04 / Account actions', [
                    _spec('Action · default', 420,
                        ProfileActionTile(
                          icon: Icons.lock_reset_outlined,
                          title: 'Change Password',
                          subtitle: 'Update your Supabase authentication password.',
                          onTap: () {},
                        )),
                    _spec('Action · destructive', 420,
                        ProfileActionTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'End session and return to authentication screen.',
                          isDestructive: true,
                          onTap: () {},
                        )),
                    _spec('Action · disabled', 420,
                        const ProfileActionTile(
                          icon: Icons.lock_reset_outlined,
                          title: 'Change Password',
                          subtitle: 'Unavailable while offline.',
                        )),
                    _spec('Buttons', 520, Wrap(spacing: 8, runSpacing: 8, children: [
                      ProfileButton(label: 'Save', kind: ProfileButtonKind.primary, onPressed: () {}),
                      ProfileButton(label: 'Cancel', onPressed: () {}),
                      ProfileButton(label: 'Sign Out', kind: ProfileButtonKind.danger, onPressed: () {}),
                      const ProfileButton(label: 'Disabled', kind: ProfileButtonKind.primary),
                      const ProfileButton(
                          label: 'Save', kind: ProfileButtonKind.primary, loading: true, loadingLabel: 'Saving'),
                    ])),
                  ]),
                  _group('05 / Form field states', [
                    _spec('Default (placeholder)', 340,
                        ProfileField(label: 'Name', required: true, controller: _nameEmpty, hint: 'Your name')),
                    _spec('Filled', 340,
                        ProfileField(label: 'Name', required: true, controller: _name)),
                    _spec('Focused (lime)', 340,
                        ProfileField(label: 'Caption', controller: _caption)),
                    _spec('Validation error', 340,
                        ProfileField(label: 'Name', required: true, controller: _nameEmpty, hint: 'Your name', errorText: 'Name is required')),
                    _spec('Disabled / saving', 340,
                        ProfileField(label: 'Name', required: true, controller: _name, enabled: false)),
                  ]),
                  _group('06 / Edit Profile dialog', [
                    _spec('Edit · default', 460,
                        ProfileDialogSurface(
                          eyebrow: 'Identity / edit', title: 'Edit Profile', icon: Icons.person_outline,
                          scrollBody: false,
                          actions: [
                            ProfileButton(label: 'Cancel', onPressed: () {}),
                            ProfileButton(label: 'Save', kind: ProfileButtonKind.primary, onPressed: () {}),
                          ],
                          child: ProfileEditFormBody(
                            previewName: 'Hamza', nameController: _name,
                            captionController: _caption, avatarController: _avatar,
                          ),
                        )),
                    _spec('Edit · validation + save error + uploading', 460,
                        ProfileDialogSurface(
                          eyebrow: 'Identity / edit', title: 'Edit Profile', icon: Icons.person_outline,
                          scrollBody: false,
                          actions: [
                            ProfileButton(label: 'Cancel', onPressed: () {}),
                            ProfileButton(label: 'Save', kind: ProfileButtonKind.primary, onPressed: () {}),
                          ],
                          child: ProfileEditFormBody(
                            previewName: 'Hamza', nameController: _nameEmpty,
                            captionController: _caption, avatarController: _avatarUrl,
                            nameError: 'Name is required',
                            saveError: 'Could not save your profile. Please try again.',
                            uploading: true,
                          ),
                        )),
                    _spec('Edit · saving', 460,
                        ProfileDialogSurface(
                          eyebrow: 'Identity / edit', title: 'Edit Profile', icon: Icons.person_outline,
                          scrollBody: false,
                          actions: [
                            const ProfileButton(label: 'Cancel'),
                            const ProfileButton(
                                label: 'Save', kind: ProfileButtonKind.primary, loading: true, loadingLabel: 'Saving'),
                          ],
                          child: ProfileEditFormBody(
                            previewName: 'Hamza', nameController: _name,
                            captionController: _caption, avatarController: _avatar, saving: true,
                          ),
                        )),
                  ]),
                  _group('07 / Change Password + Sign Out dialogs', [
                    _spec('Password · default', 460,
                        ProfileDialogSurface(
                          eyebrow: 'Account / security', title: 'Change Password', icon: Icons.lock_reset_outlined,
                          scrollBody: false,
                          actions: [
                            ProfileButton(label: 'Cancel', onPressed: () {}),
                            ProfileButton(label: 'Update', kind: ProfileButtonKind.primary, onPressed: () {}),
                          ],
                          child: ProfilePasswordFormBody(newController: _pw1, confirmController: _pw2),
                        )),
                    _spec('Password · validation error', 460,
                        ProfileDialogSurface(
                          eyebrow: 'Account / security', title: 'Change Password', icon: Icons.lock_reset_outlined,
                          scrollBody: false,
                          actions: [
                            ProfileButton(label: 'Cancel', onPressed: () {}),
                            ProfileButton(label: 'Update', kind: ProfileButtonKind.primary, onPressed: () {}),
                          ],
                          child: ProfilePasswordFormBody(
                            newController: _pwFilled1, confirmController: _pwFilled2,
                            error: 'Passwords do not match',
                          ),
                        )),
                    _spec('Sign out · confirmation', 420,
                        ProfileDialogSurface(
                          eyebrow: 'Account / session', title: 'Sign Out', icon: Icons.logout,
                          destructive: true, maxWidth: 420, scrollBody: false,
                          actions: [
                            ProfileButton(label: 'Cancel', onPressed: () {}),
                            ProfileButton(label: 'Sign Out', kind: ProfileButtonKind.danger, onPressed: () {}),
                          ],
                          child: const ProfileSignOutBody(),
                        )),
                  ]),
                  _group('08 / Loading + Error + Saved', [
                    _spec('Loading', 420, const SizedBox(height: 150, child: ProfileLoadingState())),
                    _spec('Error', 460, const SizedBox(height: 280, child: ProfileErrorState(message: 'Bad state: database unavailable'))),
                    _spec('Saved (snackbar)', 420, Builder(
                      builder: (ctx) => ProfileButton(
                        label: 'Trigger "Profile updated" snackbar',
                        icon: Icons.check,
                        onPressed: () => ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        ),
                      ),
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    final ink = ProfileInk.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSectionHeader(eyebrow: 'Wave 13', title: title),
          Container(height: 1, color: ink.hairline),
          const SizedBox(height: 16),
          Wrap(spacing: 20, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.start, children: children),
        ],
      ),
    );
  }

  Widget _spec(String label, double width, Widget child) {
    final ink = ProfileInk.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Text(label.toUpperCase(), style: ink.eyebrow(), maxLines: 2),
            ),
            SizedBox(width: width, child: child),
          ],
        ),
      ),
    );
  }
}
