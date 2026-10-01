import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Reusable Flutter equivalent of transitions.dev's Number pop-in recipe.
///
/// Each character re-enters independently when [value] changes. The widget is
/// intentionally opt-in so identifiers, dates, and static copy do not animate
/// just because they contain digits.
class KratosNumberPopIn extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final String? semanticsLabel;
  final int? maxLines;
  final TextOverflow? overflow;

  const KratosNumberPopIn(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.semanticsLabel,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations || value.isEmpty) {
      return Text(
        value,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final characters = value.runes.map(String.fromCharCode).toList();
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          for (var index = 0; index < characters.length; index++)
            _PopInCharacter(
              key: ValueKey('$index:${characters[index]}'),
              character: characters[index],
              style: style,
              delay: _delayFor(index, characters.length),
            ),
        ],
      ),
    );
  }

  Duration _delayFor(int index, int length) {
    final fromEnd = length - index;
    if (fromEnd == 2) return const Duration(milliseconds: 70);
    if (fromEnd == 1) return const Duration(milliseconds: 140);
    return Duration.zero;
  }
}

class _PopInCharacter extends StatefulWidget {
  final String character;
  final TextStyle? style;
  final Duration delay;

  const _PopInCharacter({
    super.key,
    required this.character,
    required this.style,
    required this.delay,
  });

  @override
  State<_PopInCharacter> createState() => _PopInCharacterState();
}

class _PopInCharacterState extends State<_PopInCharacter>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 500);
  static const _distance = 8.0;
  static const _blur = 2.0;
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.45, 0.64, 1),
    );
    _play();
  }

  @override
  void didUpdateWidget(covariant _PopInCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character != widget.character) _play();
  }

  Future<void> _play() async {
    _controller.value = 0;
    if (widget.delay > Duration.zero) await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    await _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: Text(widget.character, style: widget.style),
      builder: (context, child) {
        // The source easing intentionally has a small overshoot. Clamp the
        // visual channels that Flutter requires to stay within their bounds.
        final progress = _progress.value.clamp(0.0, 1.0).toDouble();
        final blur = _blur * (1 - progress);
        Widget result = Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, _distance * (1 - progress)),
            child: child,
          ),
        );
        if (blur > 0.05) {
          result = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: result,
          );
        }
        return result;
      },
    );
  }
}
