import 'package:flutter/material.dart';

import '../ui/constants.dart';
import '../ui/motion.dart';

/// A validation message shown directly under a field.
///
/// Errors should be calm and local: no shaking the screen, no snackbar far
/// from the field. The message grows in (height + short fade/slide) so nothing
/// below it jumps, carries an icon so it isn't colour-only, and is announced
/// to screen readers when it appears. Reduced motion swaps it instantly.
///
/// Reserve no space when [message] is null.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({super.key, required this.message, this.textAlign = TextAlign.start});

  final String? message;
  final TextAlign textAlign;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final reduce = reduceMotionOf(context);
    final error = theme.colorScheme.error;
    final text = message;

    // AnimatedSize asserts with a zero duration, so reduced motion skips the
    // animation widgets entirely rather than shortening them.
    final content = text == null
        ? const SizedBox(key: ValueKey('no-error'), width: double.infinity)
            : Semantics(
                key: ValueKey(text),
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: Row(
                    mainAxisAlignment: switch (textAlign) {
                      TextAlign.center => MainAxisAlignment.center,
                      TextAlign.end || TextAlign.right => MainAxisAlignment.end,
                      _ => MainAxisAlignment.start,
                    },
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: error),
                      const SizedBox(width: AppSpacing.s4),
                      Flexible(
                        child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: error)),
                      ),
                    ],
                  ),
                ),
              );

    if (reduce) return content;

    return AnimatedSize(
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDuration.fast,
        switchInCurve: AppCurve.standard,
        switchOutCurve: AppCurve.exit,
        transitionBuilder: (final child, final animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -0.25), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (final current, final previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: content,
      ),
    );
  }
}
