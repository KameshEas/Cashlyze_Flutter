import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../ui/constants.dart';

/// Which scene to draw. See docs/redesign/07-illustration-system.md.
enum AppIllustrationKind {
  /// Transactions: no transactions yet.
  ledger,

  /// Budgets: no budgets yet.
  envelope,

  /// Goals: no savings goals yet.
  jar,

  /// Categories: no categories yet.
  tags,

  /// EMI: no loans yet.
  calendar,

  /// Insights: no data for the period.
  chart,

  /// Search: the query matched nothing (not "no data", not "failed").
  magnifier,

  /// An operation failed. Calm: warning spot, never red.
  error,

  /// No connection. A flow line with a gap and a waiting coin.
  offline,
}

/// Colours for one scene, resolved from the app's semantic tokens so the art
/// can never drift off-palette. No illustration-only colours.
@immutable
class IllustrationPalette {
  const IllustrationPalette({
    required this.stroke,
    required this.fill,
    required this.fillSoft,
    required this.accent,
    required this.shadow,
    required this.spot,
  });

  factory IllustrationPalette.of(final Brightness brightness, {final Color? spot}) {
    final dark = brightness == Brightness.dark;
    return IllustrationPalette(
      stroke: dark ? AppColors.ocean400 : AppColors.ocean700,
      fill: dark ? AppColors.ocean800 : AppColors.tint100,
      fillSoft: dark ? AppColors.darkSurfaceHigh : AppColors.tint050,
      accent: dark ? AppColors.brandTealOnDark : AppColors.brandTeal,
      // Visible on both: ink-tinted on paper, deep black-teal on dark surfaces.
      shadow: dark ? const Color(0x66000000) : AppColors.ocean700.withValues(alpha: 0.14),
      spot: spot ?? AppColors.warning,
    );
  }

  final Color stroke;
  final Color fill;
  final Color fillSoft;
  final Color accent;

  /// Offset "paper" shadow behind solid shapes.
  final Color shadow;

  /// At most one shape per scene. `warning` by default; never `error`.
  final Color spot;
}

/// Paints one [AppIllustrationKind] on the shared 160 x 120 grid.
///
/// The common signature is the *flow baseline*, a soft wave that echoes the
/// logo swoosh. Stroke is a uniform 2.5 units with round caps and joins;
/// depth is a single flat tint plus one offset "paper" shadow shape.
class AppIllustrationPainter extends CustomPainter {
  const AppIllustrationPainter({required this.kind, required this.palette});

  final AppIllustrationKind kind;
  final IllustrationPalette palette;

  static const double gridW = 160;
  static const double gridH = 120;
  static const double _stroke = 2.5;

  @override
  void paint(final Canvas canvas, final Size size) {
    final scale = (size.width / gridW) < (size.height / gridH) ? size.width / gridW : size.height / gridH;
    canvas
      ..save()
      ..translate((size.width - gridW * scale) / 2, (size.height - gridH * scale) / 2)
      ..scale(scale);

    switch (kind) {
      case AppIllustrationKind.offline:
        _offline(canvas);
      default:
        _wave(canvas);
        switch (kind) {
          case AppIllustrationKind.ledger:
            _ledger(canvas);
          case AppIllustrationKind.envelope:
            _envelope(canvas);
          case AppIllustrationKind.jar:
            _jar(canvas);
          case AppIllustrationKind.tags:
            _tags(canvas);
          case AppIllustrationKind.calendar:
            _calendar(canvas);
          case AppIllustrationKind.chart:
            _chart(canvas);
          case AppIllustrationKind.magnifier:
            _magnifier(canvas);
          case AppIllustrationKind.error:
            _error(canvas);
          case AppIllustrationKind.offline:
            break;
        }
    }
    canvas.restore();
  }

  // ── primitives ─────────────────────────────────────────────────────────

  Paint _line(final Color c, {final double width = _stroke}) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _solid(final Color c) => Paint()..color = c;

  /// Filled shape with outline, preceded by the offset paper shadow.
  void _solidRRect(final Canvas canvas, final Rect r, {final double radius = 6, final bool shadow = true, final Color? fill}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    if (shadow) {
      canvas.drawRRect(rr.shift(const Offset(4, 4)), _solid(palette.shadow));
    }
    canvas
      ..drawRRect(rr, _solid(fill ?? palette.fill))
      ..drawRRect(rr, _line(palette.stroke));
  }

  void _dashedRRect(final Canvas canvas, final Rect r, {final double radius = 6, final Color? fill}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    if (fill != null) canvas.drawRRect(rr, _solid(fill));
    final path = Path()..addRRect(rr);
    final paint = _line(palette.stroke);
    for (final PathMetric m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, (d + 5).clamp(0, m.length)), paint);
      }
    }
  }

  void _coin(final Canvas canvas, final Offset c, final double r, {final bool filled = true}) {
    if (filled) canvas.drawCircle(c, r, _solid(palette.fillSoft));
    canvas
      ..drawCircle(c, r, _line(palette.stroke))
      ..drawCircle(c, r * 0.5, _line(palette.accent));
  }

  /// The signature: a soft wave under every scene.
  void _wave(final Canvas canvas) {
    final p = Path()
      ..moveTo(10, 104)
      ..cubicTo(35, 94, 55, 114, 80, 104)
      ..cubicTo(105, 94, 125, 114, 150, 104);
    canvas.drawPath(p, _line(palette.accent));
  }

  // ── scenes ─────────────────────────────────────────────────────────────

  void _ledger(final Canvas canvas) {
    _solidRRect(canvas, const Rect.fromLTWH(46, 14, 68, 76));
    for (var i = 0; i < 3; i++) {
      final y = 32.0 + i * 18;
      canvas
        ..drawCircle(Offset(58, y), 4, _solid(palette.accent))
        ..drawLine(Offset(68, y), Offset(i == 1 ? 90 : 100, y), _line(palette.stroke));
    }
  }

  void _envelope(final Canvas canvas) {
    // Coin peeking out of the top.
    _coin(canvas, const Offset(80, 28), 12);
    _solidRRect(canvas, const Rect.fromLTWH(38, 38, 84, 54));
    final flap = Path()
      ..moveTo(40, 40)
      ..lineTo(80, 68)
      ..lineTo(120, 40);
    canvas.drawPath(flap, _line(palette.stroke));
  }

  void _jar(final Canvas canvas) {
    // Coin about to drop in, with two motion ticks.
    _coin(canvas, const Offset(80, 12), 7, filled: false);
    canvas
      ..drawLine(const Offset(68, 8), const Offset(68, 14), _line(palette.accent))
      ..drawLine(const Offset(92, 8), const Offset(92, 14), _line(palette.accent));
    _solidRRect(canvas, const Rect.fromLTWH(56, 36, 48, 58), radius: 12);
    _solidRRect(canvas, const Rect.fromLTWH(60, 25, 40, 11), radius: 4, shadow: false, fill: palette.fillSoft);
    // Savings level.
    canvas.drawCircle(const Offset(80, 82), 7, _solid(palette.accent));
  }

  void _tags(final Canvas canvas) {
    _solidRRect(canvas, const Rect.fromLTWH(44, 20, 32, 32), shadow: false);
    _solidRRect(canvas, const Rect.fromLTWH(84, 20, 32, 32), shadow: false, fill: palette.fillSoft);
    _solidRRect(canvas, const Rect.fromLTWH(44, 60, 32, 32), shadow: false, fill: palette.fillSoft);
    // The empty slot waiting to be filled.
    _dashedRRect(canvas, const Rect.fromLTWH(84, 60, 32, 32));
    canvas
      ..drawCircle(const Offset(60, 36), 6, _solid(palette.accent))
      ..drawLine(const Offset(93, 32), const Offset(107, 32), _line(palette.stroke))
      ..drawLine(const Offset(93, 40), const Offset(103, 40), _line(palette.stroke))
      ..drawLine(const Offset(52, 76), const Offset(68, 76), _line(palette.stroke))
      ..drawLine(const Offset(52, 84), const Offset(62, 84), _line(palette.stroke))
      ..drawLine(const Offset(100, 71), const Offset(100, 81), _line(palette.accent))
      ..drawLine(const Offset(95, 76), const Offset(105, 76), _line(palette.accent));
  }

  void _calendar(final Canvas canvas) {
    _solidRRect(canvas, const Rect.fromLTWH(42, 22, 76, 70));
    canvas
      ..drawLine(const Offset(42, 42), const Offset(118, 42), _line(palette.stroke))
      ..drawLine(const Offset(62, 15), const Offset(62, 27), _line(palette.stroke))
      ..drawLine(const Offset(98, 15), const Offset(98, 27), _line(palette.stroke));
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final c = Offset(60.0 + col * 20, 57.0 + row * 18);
        if (row == 1 && col == 1) {
          canvas.drawCircle(c, 6, _solid(palette.accent));
        } else {
          canvas.drawCircle(c, 3.5, _solid(palette.stroke.withValues(alpha: 0.45)));
        }
      }
    }
  }

  void _chart(final Canvas canvas) {
    final axes = Path()
      ..moveTo(38, 20)
      ..lineTo(38, 92)
      ..lineTo(124, 92);
    canvas.drawPath(axes, _line(palette.stroke));
    const bars = [(50.0, 24.0), (74.0, 40.0), (98.0, 30.0)];
    for (final (x, h) in bars) {
      _dashedRRect(canvas, Rect.fromLTWH(x, 88 - h, 16, h), radius: 4, fill: palette.fillSoft);
    }
  }

  void _magnifier(final Canvas canvas) {
    const c = Offset(72, 52);
    canvas
      ..drawCircle(c + const Offset(4, 4), 26, _solid(palette.shadow))
      ..drawCircle(c, 26, _solid(palette.fill))
      ..drawCircle(c, 26, _line(palette.stroke))
      ..drawLine(const Offset(91, 71), const Offset(112, 92), _line(palette.stroke, width: 7));
    for (var i = -1; i <= 1; i++) {
      canvas.drawCircle(c + Offset(i * 10.0, 0), 2.5, _solid(palette.accent));
    }
  }

  void _error(final Canvas canvas) {
    _solidRRect(canvas, const Rect.fromLTWH(46, 14, 58, 72));
    canvas
      ..drawLine(const Offset(56, 32), const Offset(94, 32), _line(palette.stroke))
      ..drawLine(const Offset(56, 46), const Offset(82, 46), _line(palette.stroke));
    // "Try again" spot: a circular arrow in the warning colour, never red.
    const c = Offset(104, 76);
    canvas.drawCircle(c, 17, _solid(palette.spot.withValues(alpha: 0.22)));
    const r = 9.0;
    final arc = Rect.fromCircle(center: c, radius: r);
    final spotLine = _line(palette.spot);
    canvas.drawArc(arc, -1.2, 4.6, false, spotLine);
    final tip = Offset(c.dx + r * 0.36, c.dy - r * 0.93);
    final head = Path()
      ..moveTo(tip.dx - 5, tip.dy - 1)
      ..lineTo(tip.dx + 1, tip.dy)
      ..lineTo(tip.dx - 1, tip.dy + 6);
    canvas.drawPath(head, spotLine);
  }

  void _offline(final Canvas canvas) {
    final line = _line(palette.accent);
    final left = Path()
      ..moveTo(10, 104)
      ..cubicTo(25, 98, 38, 110, 52, 104);
    final right = Path()
      ..moveTo(108, 104)
      ..cubicTo(122, 98, 136, 110, 150, 104);
    canvas
      ..drawPath(left, line)
      ..drawPath(right, line);
    // The gap, marked rather than hidden.
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(66.0 + i * 14, 104), 1.6, _solid(palette.accent));
    }
    // A coin waiting at the broken end.
    _coin(canvas, const Offset(44, 88), 14);
  }

  @override
  bool shouldRepaint(final AppIllustrationPainter old) =>
      old.kind != kind || old.palette.stroke != palette.stroke || old.palette.spot != palette.spot;
}
