import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../ui/motion.dart';
import 'illustration_painters.dart';

export 'illustration_painters.dart' show AppIllustrationKind;

/// Picks the failure scene for an error: no connection reads differently from
/// a server or parse failure and must not look like a system fault.
AppIllustrationKind illustrationForError(final Object error) =>
    error is NetworkException || error is TimeoutException
        ? AppIllustrationKind.offline
        : AppIllustrationKind.error;

/// A purpose-built scene from the Cashlyze illustration family.
///
/// Decorative: the adjacent title carries the meaning, so it is excluded from
/// semantics. Plays one short fade + rise on entrance and skips it under
/// reduced motion. Themed from the colour scheme brightness, so one definition
/// serves light and dark.
class AppIllustration extends StatelessWidget {
  const AppIllustration(this.kind, {super.key, this.width = defaultWidth});

  final AppIllustrationKind kind;
  final double width;

  static const double defaultWidth = 160;

  /// Below this available height, or at large text scales, callers should drop
  /// the art so the title and CTA are never pushed off-screen.
  static const double minHeightForArt = 360;
  static const double maxTextScaleForArt = 1.5;

  /// Whether there is room for an illustration given [constraints] and the
  /// current text scale.
  static bool fits(final BuildContext context, final BoxConstraints constraints) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final tallEnough = !constraints.hasBoundedHeight || constraints.maxHeight >= minHeightForArt;
    return tallEnough && scale < maxTextScaleForArt;
  }

  @override
  Widget build(final BuildContext context) {
    final palette = IllustrationPalette.of(Theme.of(context).brightness);
    final reduce = reduceMotionOf(context);
    final w = width.clamp(0.0, 200.0);

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: reduce ? 1 : 0, end: 1),
        duration: reduce ? Duration.zero : AppDuration.fast,
        curve: AppCurve.standard,
        builder: (final context, final t, final child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
        ),
        child: SizedBox(
          width: w,
          height: w * AppIllustrationPainter.gridH / AppIllustrationPainter.gridW,
          child: CustomPaint(painter: AppIllustrationPainter(kind: kind, palette: palette)),
        ),
      ),
    );
  }
}
