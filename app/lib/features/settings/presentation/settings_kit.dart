// ignore_for_file: public_member_api_docs
//
// KRATOS Wave 12 — Settings component kit.
//
// One visual vocabulary for every Settings surface. Dark is the master
// design (deep black, volcanic glass, restrained acid lime); Light is the same
// geometry translated to ceramic / off-white material. Nothing in here owns
// business logic: every widget is presentation-only and driven by callbacks.
//
// Manus reference mapping (manus-visual-reference.html has no dedicated
// Settings section, so the closest approved elements are used):
//   SettingsSectionHeader → Manus `.section-header` (mono eyebrow + rule)
//   SettingsGroup         → Manus glass card material rules
//   SettingsRow           → Manus list/stat row on glass
//   SettingsButton        → Manus primary / ghost button
//   SettingsStatusPill    → Manus `.chip`

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme.dart';

/// Resolved colour tokens for the active brightness.
class SettingsTokens {
  final bool isDark;
  const SettingsTokens._(this.isDark);

  factory SettingsTokens.of(BuildContext context) =>
      SettingsTokens._(Theme.of(context).brightness == Brightness.dark);

  Color get text => isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
  Color get secondary =>
      isDark ? const Color(0xFFA2A79C) : KratosTheme.lightTextSecondary;
  Color get muted => isDark ? const Color(0xFF7C8176) : KratosTheme.lightTextMuted;
  Color get accent => isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
  Color get accentText =>
      isDark ? KratosTheme.electricLime : const Color(0xFF4A6B00);
  Color get onAccent => isDark ? KratosTheme.deepBlack : Colors.white;
  Color get hairline =>
      isDark ? const Color(0x14FFFFFF) : const Color(0x1710130F);
  Color get danger => isDark ? const Color(0xFFE5786E) : const Color(0xFFB0372D);
  Color get warning => isDark ? const Color(0xFFE2A93F) : const Color(0xFF8F5B00);
  Color get success => accentText;
  Color get disabledFill =>
      isDark ? const Color(0x0DFFFFFF) : const Color(0x0F10130F);
}

enum SettingsTone { normal, danger, warning, success }

Color _toneColor(SettingsTokens t, SettingsTone tone) => switch (tone) {
      SettingsTone.normal => t.accentText,
      SettingsTone.danger => t.danger,
      SettingsTone.warning => t.warning,
      SettingsTone.success => t.accentText,
    };

// -----------------------------------------------------------------------------
// Page scaffold
// -----------------------------------------------------------------------------

/// Standard Settings page: transparent scaffold over the KRATOS environment,
/// readable max width, staggered section entrance.
class SettingsPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final width = MediaQuery.of(context).size.width;
    final gutter = width < 600 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back, color: t.secondary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: t.accentText,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
        actions: actions,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 64),
            children: [
              KratosStaggerList(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Section header + group surface
// -----------------------------------------------------------------------------

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 2,
                      height: 11,
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: t.isDark ? 0.9 : 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title.toUpperCase(),
                        semanticsLabel: title,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10.5,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w600,
                          color: t.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.35,
                      color: t.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// A single glass / ceramic surface that holds several rows separated by
/// hairlines — keeps Settings scannable instead of a stack of floating cards.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  final bool active;
  final SettingsTone tone;
  final EdgeInsetsGeometry? padding;

  const SettingsGroup({
    super.key,
    required this.children,
    this.dividerIndent = 66,
    this.active = false,
    this.tone = SettingsTone.normal,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final radius = BorderRadius.circular(18);
    final toneColor = tone == SettingsTone.normal ? t.accent : _toneColor(t, tone);
    final highlighted = active || tone != SettingsTone.normal;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          indent: dividerIndent,
          endIndent: 0,
          color: t.hairline,
        ));
      }
      rows.add(children[i]);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: t.isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF151816).withValues(alpha: 0.96),
                  const Color(0xFF0C0F0D).withValues(alpha: 0.98),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFAFAF7).withValues(alpha: 0.94),
                  const Color(0xFFF1F0EA).withValues(alpha: 0.94),
                ],
              ),
        border: Border.all(
          color: highlighted
              ? toneColor.withValues(alpha: t.isDark ? 0.55 : 0.60)
              : (t.isDark ? const Color(0x1AFFFFFF) : const Color(0x1F10130F)),
          width: highlighted ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: t.isDark ? const Color(0x61000000) : const Color(0x0F10130F),
            blurRadius: t.isDark ? 20 : 18,
            offset: const Offset(0, 6),
          ),
          if (!t.isDark)
            const BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: t.isDark ? 0.20 : 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header + group convenience wrapper.
class SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;
  final bool active;
  final SettingsTone tone;
  final double dividerIndent;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.active = false,
    this.tone = SettingsTone.normal,
    this.dividerIndent = 66,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(
          title: title,
          description: description,
          trailing: trailing,
        ),
        SettingsGroup(
          active: active,
          tone: tone,
          dividerIndent: dividerIndent,
          children: children,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Rows
// -----------------------------------------------------------------------------

class SettingsIconTile extends StatelessWidget {
  final IconData icon;
  final SettingsTone tone;
  final bool dimmed;

  const SettingsIconTile({
    super.key,
    required this.icon,
    this.tone = SettingsTone.normal,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final color = dimmed ? t.muted : _toneColor(t, tone);
    final base = tone == SettingsTone.normal ? t.accent : color;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: dimmed
            ? t.disabledFill
            : base.withValues(alpha: t.isDark ? 0.10 : 0.14),
        border: Border.all(
          color: dimmed
              ? t.hairline
              : base.withValues(alpha: t.isDark ? 0.28 : 0.38),
        ),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Generic settings row: icon · title / description · value · chevron.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final SettingsTone tone;
  final bool enabled;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    bool? showChevron,
    this.tone = SettingsTone.normal,
    this.enabled = true,
  }) : showChevron = showChevron ?? (onTap != null);

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final interactive = onTap != null && enabled;
    final titleColor = !enabled
        ? t.muted
        : (tone == SettingsTone.danger ? t.danger : t.text);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SettingsIconTile(icon: icon, tone: tone, dimmed: !enabled),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: titleColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: t.secondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: enabled ? t.accentText : t.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: t.muted),
          ],
        ],
      ),
    );

    if (!interactive) {
      return Semantics(label: title, child: content);
    }
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        hoverColor: t.accent.withValues(alpha: t.isDark ? 0.045 : 0.07),
        splashColor: t.accent.withValues(alpha: 0.10),
        highlightColor: t.accent.withValues(alpha: 0.05),
        child: content,
      ),
    );
  }
}

/// Toggle row (existing switch semantics, KRATOS lime when enabled).
class SettingsToggleRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool busy;

  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: title,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        hoverColor: t.accent.withValues(alpha: t.isDark ? 0.045 : 0.07),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                SettingsIconTile(icon: icon!, dimmed: !enabled && !busy),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: enabled || busy ? t.text : t.muted,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: t.secondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (busy)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: t.accent,
                    ),
                  ),
                ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only label / value row (account & system information).
class SettingsInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final labelStyle = TextStyle(
      fontFamily: 'Inter',
      color: t.secondary,
      fontSize: 12.5,
    );
    final valueStyle = TextStyle(
      fontFamily: mono ? 'IBM Plex Mono' : 'Inter',
      color: t.text,
      fontSize: 12,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 4),
                Text(value, style: valueStyle),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              const SizedBox(width: 16),
              Expanded(
                child: Text(value, textAlign: TextAlign.end, style: valueStyle),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Icon · title · paragraph row for long-form informational copy.
class SettingsTextRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const SettingsTextRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsIconTile(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: t.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: t.secondary,
                    fontSize: 12.5,
                    height: 1.5,
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
// Controls
// -----------------------------------------------------------------------------

enum SettingsButtonVariant { primary, secondary, destructive }

class SettingsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SettingsButtonVariant variant;
  final bool loading;
  final bool compact;
  final bool expand;

  const SettingsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = SettingsButtonVariant.primary,
    this.loading = false,
    this.compact = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final enabled = onPressed != null && !loading;

    final Color bg;
    final Color fg;
    final Color border;
    switch (variant) {
      case SettingsButtonVariant.primary:
        bg = enabled
            ? t.accent
            : (loading ? t.accent.withValues(alpha: 0.45) : t.disabledFill);
        fg = enabled || loading ? t.onAccent : t.muted;
        border = Colors.transparent;
      case SettingsButtonVariant.secondary:
        bg = Colors.transparent;
        fg = enabled ? t.accentText : t.muted;
        border = enabled
            ? t.accent.withValues(alpha: t.isDark ? 0.45 : 0.65)
            : t.hairline;
      case SettingsButtonVariant.destructive:
        bg = enabled
            ? t.danger.withValues(alpha: t.isDark ? 0.10 : 0.08)
            : t.disabledFill;
        fg = enabled ? t.danger : t.muted;
        border = enabled ? t.danger.withValues(alpha: 0.45) : t.hairline;
    }

    final vertical = compact ? 8.0 : 12.0;
    final horizontal = compact ? 14.0 : 16.0;

    final inner = AnimatedContainer(
      duration: MediaQuery.maybeOf(context)?.disableAnimations ?? false
          ? Duration.zero
          : const Duration(milliseconds: 180),
      constraints: BoxConstraints(minHeight: compact ? 36 : 44),
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            )
          else if (icon != null)
            Icon(icon, size: compact ? 15 : 17, color: fg),
          if (loading || icon != null) SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                color: fg,
                fontSize: compact ? 12 : 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: KratosPressable(
          onTap: enabled ? onPressed : null,
          child: inner,
        ),
      ),
    );
  }
}

/// Lays buttons side by side on wide surfaces and stacks them when narrow.
class SettingsButtonRow extends StatelessWidget {
  final List<Widget> children;
  const SettingsButtonRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class SettingsSegment<T> {
  final T value;
  final String label;
  final IconData icon;
  const SettingsSegment({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Segmented selector (existing two-option theme switch).
class SettingsSegmented<T> extends StatelessWidget {
  final List<SettingsSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  const SettingsSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: t.isDark ? const Color(0x08FFFFFF) : const Color(0x0A10130F),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                selected: segments[i].value == value,
                label: segments[i].label,
                child: KratosPressable(
                  onTap: () => onChanged(segments[i].value),
                  child: AnimatedContainer(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: segments[i].value == value
                          ? t.accent.withValues(alpha: t.isDark ? 0.14 : 0.18)
                          : Colors.transparent,
                      border: Border.all(
                        color: segments[i].value == value
                            ? t.accent.withValues(alpha: t.isDark ? 0.85 : 0.9)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          segments[i].icon,
                          size: 16,
                          color: segments[i].value == value
                              ? t.accentText
                              : t.secondary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            segments[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              letterSpacing: 0.8,
                              fontWeight: segments[i].value == value
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: segments[i].value == value
                                  ? t.accentText
                                  : t.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small status chip (permission state, HLC health, etc.).
class SettingsStatusPill extends StatelessWidget {
  final String label;
  final SettingsTone tone;
  const SettingsStatusPill({
    super.key,
    required this.label,
    this.tone = SettingsTone.normal,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final color = _toneColor(t, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: t.isDark ? 0.10 : 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 9.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Feedback surfaces
// -----------------------------------------------------------------------------

class SettingsBanner extends StatelessWidget {
  final String message;
  final SettingsTone tone;
  final IconData? icon;

  const SettingsBanner({
    super.key,
    required this.message,
    this.tone = SettingsTone.success,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final color = _toneColor(t, tone);
    final resolvedIcon = icon ??
        switch (tone) {
          SettingsTone.danger => Icons.error_outline,
          SettingsTone.warning => Icons.warning_amber_rounded,
          _ => Icons.check_circle_outline,
        };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: t.isDark ? 0.09 : 0.10),
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(resolvedIcon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: tone == SettingsTone.success ? t.text : color,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsEmptyBlock extends StatelessWidget {
  final IconData icon;
  final String message;
  const SettingsEmptyBlock({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsIconTile(icon: icon, dimmed: true),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              color: t.secondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsLoadingBlock extends StatelessWidget {
  const SettingsLoadingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: t.accent),
        ),
      ),
    );
  }
}

/// Modal surface used for Settings dialogs (ceramic in Light, glass in Dark).
class SettingsDialog extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;
  final List<Widget> actions;

  const SettingsDialog({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: t.isDark ? const Color(0xFF0F1210) : const Color(0xFFFAFAF7),
            border: Border.all(
              color: t.isDark ? const Color(0x2EFFFFFF) : const Color(0x2610130F),
            ),
            boxShadow: [
              BoxShadow(
                color: t.isDark ? const Color(0x99000000) : const Color(0x2210130F),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: t.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 16),
                child,
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions[i],
                    ],
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
