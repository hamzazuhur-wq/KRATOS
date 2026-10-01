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
    return showDialog<String>(
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
    return AlertDialog(
      backgroundColor: const Color(0xFF141714),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Color(0xFFC6F135),
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 1.1,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        textInputAction: widget.maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: (_) => _submit(),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: const Color(0xFF1A1D1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC6F135)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC6F135),
            foregroundColor: Colors.black,
          ),
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
