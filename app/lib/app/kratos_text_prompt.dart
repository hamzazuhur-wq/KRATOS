// ignore_for_file: public_member_api_docs
//
// Shared single-field prompt dialog for KRATOS.
//
// Why this exists: creating a `TextEditingController` next to a `showDialog`
// call and disposing it as soon as the future resolves is a crash — the dialog
// route is still animating out and rebuilds with a disposed controller
// ("A TextEditingController was used after being disposed"). That made inline
// creation flows (new skill group, rename, etc.) silently fail.
//
// This widget owns its controller, so disposal happens exactly when the route
// is torn down.

import 'package:flutter/material.dart';

import 'kratos_motion.dart';
import 'kratos_theme.dart';
import 'kratos_visuals.dart';

class KratosTextPrompt extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final int maxLines;

  const KratosTextPrompt({
    super.key,
    required this.title,
    required this.label,
    this.initialValue = '',
    this.confirmLabel = 'SAVE',
    this.keyboardType,
    this.maxLines = 1,
  });

  /// Shows the prompt and resolves with the trimmed value, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    String initialValue = '',
    String confirmLabel = 'SAVE',
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return showKratosDialog<String>(
      context: context,
      builder: (_) => KratosTextPrompt(
        title: title,
        label: label,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }

  @override
  State<KratosTextPrompt> createState() => _KratosTextPromptState();
}

class _KratosTextPromptState extends State<KratosTextPrompt> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initialValue.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(value);
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: widget.maxLines,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.maxLines > 1
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.label,
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: mutedColor.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF141714)
                        : Colors.white.withValues(alpha: 0.7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: lime, width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: mutedColor,
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    KratosPressable(
                      onTap: _submit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            if (isDark)
                              BoxShadow(
                                color: lime.withValues(alpha: 0.2),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Text(
                          widget.confirmLabel.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF020302) : Colors.white,
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
