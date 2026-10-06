// KRATOS Wave 13 — Profile / Account / Identity visual components.
//
// Presentation-only widgets shared by [ProfileScreen] and the Wave 13
// storybook. Every widget is theme-aware (Dark = master design, Light = same
// geometry with Light material) and holds NO business logic.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../domain/profile_models.dart';

/// Resolved ink / material tokens for the Profile surfaces.
class ProfileInk {
  final bool isDark;
  const ProfileInk(this.isDark);

  factory ProfileInk.of(BuildContext context) =>
      ProfileInk(Theme.of(context).brightness == Brightness.dark);

  Color get primary =>
      isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
  Color get secondary =>
      isDark ? const Color(0xFFADB2A8) : KratosTheme.lightTextSecondary;
  Color get muted =>
      isDark ? const Color(0xFF8A9086) : const Color(0xFF6E7480);

  /// Accent used for text / icons / strokes.
  Color get accent =>
      isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;

  /// Accent used for solid fills (primary button).
  Color get accentFill =>
      isDark ? KratosTheme.electricLime : const Color(0xFFA8B800);
  Color get onAccent =>
      isDark ? const Color(0xFF121500) : const Color(0xFF10130F);
  Color get danger =>
      isDark ? const Color(0xFFFF5A4F) : const Color(0xFFC4271D);
  Color get hairline =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x1A10130F);
  Color get ringFill =>
      isDark ? const Color(0xFF151A12) : const Color(0xFFE7ECE4);

  TextStyle eyebrow({Color? color}) => TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontSize: 10,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
        color: color ?? muted,
      );

  TextStyle display(double size, {Color? color, FontWeight? weight}) =>
      TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.15,
        color: color ?? primary,
      );

  TextStyle body(double size, {Color? color, FontWeight? weight}) => TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        height: 1.4,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? secondary,
      );
}

Uint8List? _decodeDataUri(String uri) {
  try {
    return base64Decode(uri.split(',').last);
  } catch (_) {
    return null;
  }
}

// -----------------------------------------------------------------------------
// Avatar
// -----------------------------------------------------------------------------

/// Identity avatar: image, initials fallback, uploading state, optional edit badge.
class ProfileAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final bool uploading;
  final VoidCallback? onEdit;

  const ProfileAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 104,
    this.uploading = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final url = avatarUrl;
    final hasImage = url != null && url.isNotEmpty;
    final fallback = _ProfileInitials(name: name, size: size);

    Widget image = fallback;
    if (hasImage) {
      if (url.startsWith('data:image')) {
        final bytes = _decodeDataUri(url);
        image = bytes == null
            ? fallback
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              );
      } else {
        image = Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        );
      }
    }

    final badge = size * 0.30;
    return Semantics(
      label: 'Profile avatar for $name',
      image: true,
      child: SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ink.accent.withValues(alpha: ink.isDark ? 0.55 : 0.60),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ink.accent.withValues(alpha: ink.isDark ? 0.14 : 0.10),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      if (uploading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: size * 0.22,
                            height: size * 0.22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ink.isDark
                                  ? KratosTheme.electricLime
                                  : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (onEdit != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Tooltip(
                  message: 'Edit profile',
                  child: KratosPressable(
                    onTap: onEdit,
                    child: Container(
                      width: badge < 28 ? 28 : badge,
                      height: badge < 28 ? 28 : badge,
                      decoration: BoxDecoration(
                        color: ink.accentFill,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ink.isDark
                              ? KratosTheme.deepBlack
                              : KratosTheme.lightBackground,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(Icons.photo_camera_outlined,
                          color: ink.onAccent, size: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInitials extends StatelessWidget {
  final String name;
  final double size;
  const _ProfileInitials({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty
        ? String.fromCharCode(trimmed.runes.first).toUpperCase()
        : 'K';
    return Container(
      color: ink.ringFill,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: ink.display(size * 0.38, color: ink.accent, weight: FontWeight.w700),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Buttons
// -----------------------------------------------------------------------------

enum ProfileButtonKind { primary, secondary, danger }

/// Manus `.btn` — primary (lime) / secondary (rim) / danger.
class ProfileButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final ProfileButtonKind kind;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  const ProfileButton({
    super.key,
    required this.label,
    this.icon,
    this.kind = ProfileButtonKind.secondary,
    this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final enabled = onPressed != null && !loading;

    final Color bg;
    final Color fg;
    final Color border;
    List<BoxShadow>? shadow;
    switch (kind) {
      case ProfileButtonKind.primary:
        bg = ink.accentFill;
        fg = ink.onAccent;
        border = Colors.transparent;
        if (ink.isDark) {
          shadow = [
            BoxShadow(
              color: KratosTheme.electricLime.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];
        }
      case ProfileButtonKind.secondary:
        bg = ink.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xB8E7ECE4);
        fg = ink.primary;
        border = ink.isDark
            ? KratosTheme.electricLime.withValues(alpha: 0.25)
            : const Color(0x1A10130F);
      case ProfileButtonKind.danger:
        bg = ink.danger.withValues(alpha: ink.isDark ? 0.12 : 0.09);
        fg = ink.danger;
        border = ink.danger.withValues(alpha: ink.isDark ? 0.45 : 0.40);
    }

    final text = loading ? (loadingLabel ?? label) : label;
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Opacity(
          opacity: (onPressed == null && !loading) ? 0.45 : 1,
          child: KratosPressable(
            onTap: enabled ? onPressed : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
                boxShadow: shadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    ),
                    const SizedBox(width: 9),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 16, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: fg,
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
}

// -----------------------------------------------------------------------------
// Section header
// -----------------------------------------------------------------------------

class ProfileSectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  const ProfileSectionHeader({super.key, required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(), style: ink.eyebrow()),
          const SizedBox(height: 4),
          Text(title, style: ink.display(17)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Header (identity anchor)
// -----------------------------------------------------------------------------

/// Identity header — the strongest visual anchor of the Profile surface.
class ProfileHeaderCard extends StatelessWidget {
  final UserProfileData profile;
  final VoidCallback? onEdit;
  final bool uploading;

  const ProfileHeaderCard({
    super.key,
    required this.profile,
    this.onEdit,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final hasCaption = profile.caption != null && profile.caption!.isNotEmpty;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.elevated,
      borderRadius: BorderRadius.circular(24),
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 560;
          final avatar = ProfileAvatar(
            name: profile.displayName,
            avatarUrl: profile.avatarUrl,
            size: wide ? 112 : 96,
            uploading: uploading,
            onEdit: onEdit,
          );
          final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
          final textAlign = wide ? TextAlign.start : TextAlign.center;
          final info = Column(
            crossAxisAlignment: align,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('OPERATIVE IDENTITY', style: ink.eyebrow(color: ink.accent)),
              const SizedBox(height: 8),
              Text(
                profile.displayName,
                textAlign: textAlign,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ink.display(wide ? 32 : 26, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                hasCaption ? profile.caption! : 'Who you are and who you want to be',
                textAlign: textAlign,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: ink.body(
                  13.5,
                  color: hasCaption ? ink.secondary : ink.muted,
                ).copyWith(fontStyle: hasCaption ? FontStyle.normal : FontStyle.italic),
              ),
              if (onEdit != null) ...[
                const SizedBox(height: 18),
                ProfileButton(
                  label: 'Edit profile',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
              ],
            ],
          );

          return Padding(
            padding: EdgeInsets.all(wide ? 28 : 22),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      avatar,
                      const SizedBox(width: 28),
                      Expanded(child: info),
                    ],
                  )
                : Column(children: [avatar, const SizedBox(height: 18), info]),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Progression
// -----------------------------------------------------------------------------

class ProfileProgressionCard extends StatelessWidget {
  final UserProfileData profile;
  const ProfileProgressionCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    Widget cell(IconData icon, String label, String value, Color valueColor, {bool expand = true}) {
      final item = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: ink.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ink.eyebrow(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ink.display(18, color: valueColor),
          ),
        ],
      );
      return expand ? Expanded(child: item) : item;
    }

    return KratosGlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(Icons.stars_outlined, 'Primary XP domain', profile.primaryXpDomain,
                    ink.accent, expand: false),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(height: 1, color: ink.hairline),
                ),
                cell(Icons.military_tech_outlined, 'Highest level', profile.highestLevel,
                    ink.primary, expand: false),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell(Icons.stars_outlined, 'Primary XP domain', profile.primaryXpDomain,
                    ink.accent),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: ink.hairline,
                ),
                cell(Icons.military_tech_outlined, 'Highest level', profile.highestLevel,
                    ink.primary),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Account information
// -----------------------------------------------------------------------------

class ProfileAccountCard extends StatelessWidget {
  final UserProfileData profile;
  const ProfileAccountCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final created =
        '${profile.createdAt.year}-${profile.createdAt.month.toString().padLeft(2, '0')}-${profile.createdAt.day.toString().padLeft(2, '0')}';

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(height: 1, color: ink.hairline),
        );

    return KratosGlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        children: [
          ProfileDetailRow(
            label: 'Email',
            value: profile.email ?? 'Not provided',
            icon: Icons.mail_outline,
          ),
          divider(),
          ProfileDetailRow(
            label: 'Account Status',
            value: 'Active • Supabase / Offline',
            icon: Icons.verified_user_outlined,
            valueColor: ink.accent,
            leadingDot: true,
          ),
          divider(),
          ProfileDetailRow(
            label: 'User ID',
            value: profile.userId.value,
            icon: Icons.fingerprint,
            isMonospace: true,
          ),
          divider(),
          ProfileDetailRow(
            label: 'Member Since',
            value: created,
            icon: Icons.calendar_today_outlined,
            isMonospace: true,
          ),
        ],
      ),
    );
  }
}

/// Label above value. Stacked layout keeps long emails / IDs readable at
/// every width without clipping.
class ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool isMonospace;
  final bool leadingDot;

  const ProfileDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.isMonospace = false,
    this.leadingDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: ink.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: ink.eyebrow()),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leadingDot) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: valueColor ?? ink.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: isMonospace ? 'IBM Plex Mono' : 'Inter',
                        fontSize: isMonospace ? 12 : 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: valueColor ?? ink.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Account actions
// -----------------------------------------------------------------------------

class ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final tone = isDestructive ? ink.danger : ink.accent;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: KratosGlassCard(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        accentColor: tone,
        interactive: true,
        disabled: onTap == null,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: ink.isDark ? 0.10 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tone.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, color: tone, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ink.body(14,
                        color: isDestructive ? ink.danger : ink.primary,
                        weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ink.body(11.5, color: ink.secondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18,
                color: isDestructive ? ink.danger.withValues(alpha: 0.6) : ink.muted),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// States
// -----------------------------------------------------------------------------

class ProfileLoadingState extends StatelessWidget {
  const ProfileLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink.accent),
          ),
          const SizedBox(height: 16),
          Text('LOADING IDENTITY', style: ink.eyebrow()),
        ],
      ),
    );
  }
}

class ProfileErrorState extends StatelessWidget {
  final String message;
  const ProfileErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: KratosGlassCard(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: ink.danger.withValues(alpha: 0.10),
                    border: Border.all(color: ink.danger.withValues(alpha: 0.35)),
                  ),
                  child: Icon(Icons.error_outline, color: ink.danger, size: 24),
                ),
                const SizedBox(height: 14),
                Text('PROFILE / ERROR', style: ink.eyebrow()),
                const SizedBox(height: 6),
                Text('Failed to load profile', style: ink.display(18)),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: ink.body(12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline notice (validation / save / auth error).
class ProfileNotice extends StatelessWidget {
  final String message;
  const ProfileNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ink.danger.withValues(alpha: ink.isDark ? 0.10 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ink.danger.withValues(alpha: 0.38)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: ink.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: ink.body(12, color: ink.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Forms & dialogs
// -----------------------------------------------------------------------------

/// Labelled field (Manus `.input`), themed focus = restrained lime.
class ProfileField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController? controller;
  final String? hint;
  final String? errorText;
  final bool obscure;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Widget? labelAction;
  final bool autofocus;

  const ProfileField({
    super.key,
    required this.label,
    this.required = false,
    this.controller,
    this.hint,
    this.errorText,
    this.obscure = false,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.labelAction,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label.toUpperCase(),
                  style: ink.eyebrow(color: ink.secondary),
                  children: [
                    if (required)
                      TextSpan(text: '  *', style: ink.eyebrow(color: ink.accent)),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?labelAction,
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          enabled: enabled,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          cursorColor: ink.accent,
          style: ink.body(13.5, color: ink.primary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ink.body(13, color: ink.muted),
            errorText: errorText,
            errorStyle: ink.body(11.5, color: ink.danger),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }
}

/// Modal surface (Manus E4): glass card + eyebrow + title + body + actions.
class ProfileDialogSurface extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData? icon;
  final bool destructive;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  /// When true (real dialogs) the body scrolls within bounded height.
  /// Inline previews pass false.
  final bool scrollBody;

  const ProfileDialogSurface({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    required this.actions,
    this.icon,
    this.destructive = false,
    this.maxWidth = 460,
    this.scrollBody = true,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    final tone = destructive ? ink.danger : ink.accent;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.elevated,
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: tone.withValues(alpha: 0.10),
                      border: Border.all(color: tone.withValues(alpha: 0.30)),
                    ),
                    child: Icon(icon, size: 18, color: tone),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow.toUpperCase(), style: ink.eyebrow(color: tone)),
                      const SizedBox(height: 3),
                      Text(title, style: ink.display(19)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (scrollBody)
              Flexible(child: SingleChildScrollView(child: child))
            else
              child,
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a Profile dialog using the shared KRATOS modal entrance.
Future<T?> showProfileDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showKratosDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: builder(ctx),
    ),
  );
}

/// Edit Profile form body (name, caption, avatar). Pure presentation.
class ProfileEditFormBody extends StatelessWidget {
  final String previewName;
  final TextEditingController nameController;
  final TextEditingController captionController;
  final TextEditingController avatarController;
  final String? nameError;
  final String? saveError;
  final bool uploading;
  final bool saving;
  final VoidCallback? onPickAvatar;

  const ProfileEditFormBody({
    super.key,
    required this.previewName,
    required this.nameController,
    required this.captionController,
    required this.avatarController,
    this.nameError,
    this.saveError,
    this.uploading = false,
    this.saving = false,
    this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saveError != null) ...[
          ProfileNotice(message: saveError!),
          const SizedBox(height: 14),
        ],
        ListenableBuilder(
          listenable: Listenable.merge([nameController, avatarController]),
          builder: (context, _) => Align(
            alignment: Alignment.centerLeft,
            child: ProfileAvatar(
              name: nameController.text.isEmpty ? previewName : nameController.text,
              avatarUrl: avatarController.text.trim(),
              size: 64,
              uploading: uploading,
            ),
          ),
        ),
        const SizedBox(height: 18),
        ProfileField(
          label: 'Name',
          required: true,
          controller: nameController,
          hint: 'Your name',
          errorText: nameError,
          enabled: !saving,
        ),
        const SizedBox(height: 16),
        ProfileField(
          label: 'Who you are and who you want to be',
          controller: captionController,
          hint: 'Who you are and who you want to be',
          maxLines: 2,
          enabled: !saving,
        ),
        const SizedBox(height: 16),
        ProfileField(
          label: 'Avatar image',
          controller: avatarController,
          hint: 'https://... or pick from device',
          enabled: !saving,
          labelAction: GestureDetector(
            onTap: (uploading || saving) ? null : onPickAvatar,
            child: MouseRegion(
              cursor: (uploading || saving)
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uploading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: ink.accent),
                      )
                    else
                      Icon(Icons.photo_library_outlined,
                          size: 14,
                          color: (saving) ? ink.muted : ink.accent),
                    const SizedBox(width: 6),
                    Text(
                      uploading ? 'Uploading…' : 'Pick from device',
                      style: ink.body(11.5,
                          color: saving ? ink.muted : ink.accent,
                          weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Change-password form body. Pure presentation.
class ProfilePasswordFormBody extends StatelessWidget {
  final TextEditingController newController;
  final TextEditingController confirmController;
  final String? error;
  final bool saving;

  const ProfilePasswordFormBody({
    super.key,
    required this.newController,
    required this.confirmController,
    this.error,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          ProfileNotice(message: error!),
          const SizedBox(height: 14),
        ],
        ProfileField(
          label: 'New password',
          required: true,
          controller: newController,
          obscure: true,
          hint: 'Enter new password',
          enabled: !saving,
        ),
        const SizedBox(height: 16),
        ProfileField(
          label: 'Confirm new password',
          required: true,
          controller: confirmController,
          obscure: true,
          hint: 'Confirm new password',
          enabled: !saving,
        ),
      ],
    );
  }
}

/// Sign-out confirmation body copy (existing confirmation pattern preserved).
class ProfileSignOutBody extends StatelessWidget {
  const ProfileSignOutBody({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = ProfileInk.of(context);
    return Text(
      'Are you sure you want to sign out of KRATOS? Your local data will remain securely saved.',
      style: ink.body(13),
    );
  }
}
