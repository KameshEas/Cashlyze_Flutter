import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/constants.dart';

/// Brand background: layered, slowly drifting arcs that echo the logo's
/// wave. Replaces the old oversized-"C" watermarks on splash/auth.
///
/// - [FlowBackdrop.ocean] — deep ocean-teal gradient with pale arcs (splash,
///   Home hero, dark auth).
/// - [FlowBackdrop.paper]  — cool paper with faint teal arcs (light auth).
///
/// Purely decorative: ignores touches and is excluded from semantics.
class FlowBackdrop extends StatelessWidget {
  const FlowBackdrop.ocean({super.key, this.drift, this.child}) : _ocean = true;
  const FlowBackdrop.paper({super.key, this.drift, this.child}) : _ocean = false;

  final bool _ocean;

  /// Optional 0 → 1 (looping) animation that nudges the arcs.
  final Animation<double>? drift;
  final Widget? child;

  @override
  Widget build(final BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _FlowPainter(ocean: _ocean, drift: drift),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({required this.ocean, this.drift}) : super(repaint: drift);

  final bool ocean;
  final Animation<double>? drift;

  @override
  void paint(final Canvas canvas, final Size size) {
    final w = size.width;
    final h = size.height;
    final d = (drift?.value ?? 0) * 2 * math.pi;
    final bounds = Offset.zero & size;

    if (ocean) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.ocean700, AppColors.ocean800, AppColors.ocean900],
            stops: [0, 0.45, 1],
          ).createShader(bounds),
      );
    } else {
      canvas.drawRect(bounds, Paint()..color = AppColors.paper);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;

    final light = ocean ? Colors.white : AppColors.ocean600;
    final a1 = ocean ? 0.07 : 0.07;
    final a2 = ocean ? 0.05 : 0.05;

    // Big sweeping ring entering from the right edge.
    ring
      ..strokeWidth = w * 0.18
      ..color = light.withValues(alpha: a1);
    canvas.drawCircle(Offset(w * 1.0 + math.sin(d) * 8, h * 0.34), w * 0.9, ring);

    // Second ring from bottom-left, thinner.
    ring
      ..strokeWidth = w * 0.09
      ..color = light.withValues(alpha: a2);
    canvas.drawCircle(Offset(-w * 0.05, h * 0.92 + math.cos(d) * 8), w * 0.78, ring);

    // Soft disc glow top-left for depth.
    fill.shader = RadialGradient(
      colors: [light.withValues(alpha: ocean ? 0.16 : 0.12), light.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: Offset(w * 0.1, h * 0.04), radius: w * 0.7));
    canvas.drawCircle(Offset(w * 0.1, h * 0.04), w * 0.7, fill);
  }

  @override
  bool shouldRepaint(final _FlowPainter old) => old.ocean != ocean;
}

/// Just the brand arcs (no background fill), for layering over a gradient
/// card such as Home's balance card.
class FlowArcs extends StatelessWidget {
  const FlowArcs({super.key});

  @override
  Widget build(final BuildContext context) => const ExcludeSemantics(
        child: IgnorePointer(child: CustomPaint(painter: _ArcsPainter())),
      );
}

class _ArcsPainter extends CustomPainter {
  const _ArcsPainter();

  @override
  void paint(final Canvas canvas, final Size size) {
    final w = size.width;
    final h = size.height;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = h * 0.34;
    canvas.drawCircle(Offset(w * 1.02, h * 0.1), h * 0.95, ring);
    ring
      ..strokeWidth = h * 0.16
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(w * 0.9, h * 1.15), h * 0.9, ring);
    final glowCenter = Offset(w * 0.08, h * 0.02);
    canvas.drawCircle(
      glowCenter,
      h * 0.9,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: h * 0.9)),
    );
  }

  @override
  bool shouldRepaint(final _ArcsPainter old) => false;
}
