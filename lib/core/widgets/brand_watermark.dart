import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative oversized outline of the brand mark's open "C" loop — the
/// swoosh that begins the Cashlyze wordmark — used as a faint background
/// accent on splash/auth screens. Purely decorative: sits behind content
/// and never intercepts touches.
class BrandWatermark extends StatelessWidget {
  const BrandWatermark({
    super.key,
    this.alignment = Alignment.topRight,
    this.offset = Offset.zero,
    this.opacity = 0.25,
    this.scale = 1.15,
    this.color,
  });

  /// Where the (oversized) mark is anchored before [offset] nudges it,
  /// typically off-screen so only part of the ring bleeds into view.
  final Alignment alignment;

  /// Extra translation applied after alignment, in logical pixels.
  final Offset offset;

  /// Alpha applied to [color] (or the theme's primary color).
  final double opacity;

  /// Diameter of the mark as a multiple of the screen width.
  final double scale;

  final Color? color;

  @override
  Widget build(final BuildContext context) {
    final brandColor = color ?? Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context).width * scale;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Transform.translate(
            offset: offset,
            child: CustomPaint(
              size: Size.square(size),
              painter: _BrandCPainter(
                color: brandColor.withValues(alpha: opacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandCPainter extends CustomPainter {
  _BrandCPainter({required this.color});

  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final strokeWidth = size.width * 0.09;
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Echoes the wordmark's leading "C": a near-full ring left open on the
    // lower-right, the same gap the logo's swoosh flows out through.
    const startAngle = -math.pi * 0.62;
    const sweepAngle = math.pi * 1.55;
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant final _BrandCPainter oldDelegate) =>
      oldDelegate.color != color;
}
