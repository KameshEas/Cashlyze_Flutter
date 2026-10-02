import 'package:flutter/material.dart';

import 'cashlyze_logo_data.dart';

/// The Cashlyze lockup from the brand kit, painted from its own vector
/// geometry ([kCashlyzeWordmarkParts] / [kCashlyzeTagline]) so it can be
/// choreographed instead of just faded:
///
/// 1. the C-and-wave swoosh sweeps in left → right, like a stroke of money
///    flowing;
/// 2. a-s-h-l-y-z-e rise into place one after another, riding the wave;
/// 3. the tagline fades in last.
///
/// Drive it with an [Animation] running 0 → 1. At `progress == 1` it is
/// pixel-identical to the static SVG lockup.
class AnimatedBrandLogo extends StatelessWidget {
  const AnimatedBrandLogo({
    super.key,
    required this.progress,
    required this.color,
    this.taglineColor,
    this.showTagline = true,
    this.width = 240,
  });

  final Animation<double> progress;

  /// Wordmark colour (kit: teal `#228992` on light, white on dark).
  final Color color;

  /// Tagline colour. Defaults to [color]; the kit's light variant uses grey.
  final Color? taglineColor;
  final bool showTagline;

  /// Logical width; height follows the lockup's aspect ratio.
  final double width;

  @override
  Widget build(final BuildContext context) {
    final logicalHeight = showTagline ? kCashlyzeLogoHeight : kCashlyzeTaglineTop;
    return Semantics(
      label: 'Cashlyze. Know where your money flows.',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width * logicalHeight / kCashlyzeLogoWidth,
        child: CustomPaint(
          painter: _LogoPainter(
            progress: progress,
            color: color,
            taglineColor: taglineColor ?? color,
            showTagline: showTagline,
          ),
        ),
      ),
    );
  }
}

/// Convenience: plays [AnimatedBrandLogo] once on mount.
class PlayOnceBrandLogo extends StatefulWidget {
  const PlayOnceBrandLogo({
    super.key,
    required this.color,
    this.taglineColor,
    this.showTagline = true,
    this.width = 240,
    this.duration = const Duration(milliseconds: 1500),
    this.delay = Duration.zero,
  });

  final Color color;
  final Color? taglineColor;
  final bool showTagline;
  final double width;
  final Duration duration;
  final Duration delay;

  @override
  State<PlayOnceBrandLogo> createState() => _PlayOnceBrandLogoState();
}

class _PlayOnceBrandLogoState extends State<PlayOnceBrandLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => AnimatedBrandLogo(
        progress: _c,
        color: widget.color,
        taglineColor: widget.taglineColor,
        showTagline: widget.showTagline,
        width: widget.width,
      );
}

Path _polygonPath(final Iterable<List<double>> polygons) {
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final poly in polygons) {
    path.moveTo(poly[0], poly[1]);
    for (var i = 2; i < poly.length; i += 2) {
      path.lineTo(poly[i], poly[i + 1]);
    }
    path.close();
  }
  return path;
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({
    required this.progress,
    required this.color,
    required this.taglineColor,
    required this.showTagline,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color taglineColor;
  final bool showTagline;

  // Built once: parts[0] is the swoosh, parts[1..7] the letters a-s-h-l-y-z-e.
  static final List<Path> _parts = [for (final p in kCashlyzeWordmarkParts) _polygonPath(p)];
  static final Path _tagline = _polygonPath(kCashlyzeTagline);
  static final List<Rect> _bounds = [for (final p in _parts) p.getBounds()];

  static double _span(final double t, final double start, final double end, final Curve curve) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  void paint(final Canvas canvas, final Size size) {
    final t = progress.value;
    final s = size.width / kCashlyzeLogoWidth;
    canvas.save();
    canvas.scale(s);

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    // 1) Swoosh: left-to-right wipe with a soft leading edge.
    final wipe = _span(t, 0.0, 0.5, Curves.easeInOutCubic);
    if (wipe > 0) {
      const w = kCashlyzeLogoWidth;
      const edge = 70.0;
      final reveal = wipe * (w + edge);
      final a = ((reveal - edge) / w).clamp(0.0, 1.0);
      final b = (reveal / w).clamp(0.0, 1.0);
      const layer = Rect.fromLTWH(0, 0, w, kCashlyzeLogoHeight);
      canvas.saveLayer(layer, Paint());
      canvas.drawPath(_parts[0], fill);
      canvas.drawRect(
        layer,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(
            colors: const [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
            stops: [0, a, b, 1],
          ).createShader(layer),
      );
      canvas.restore();
    }

    // 2) Letters: staggered rise + fade, left to right.
    for (var i = 1; i < _parts.length; i++) {
      final start = 0.26 + (i - 1) * 0.065;
      final p = _span(t, start, start + 0.26, Curves.easeOutCubic);
      if (p <= 0) continue;
      final bounds = _bounds[i];
      canvas.save();
      // Rise from 16 logo-units below, growing slightly from the baseline.
      canvas.translate(bounds.center.dx, bounds.bottom + (1 - p) * 16);
      canvas.scale(0.9 + 0.1 * p);
      canvas.translate(-bounds.center.dx, -bounds.bottom);
      canvas.drawPath(
        _parts[i],
        Paint()
          ..color = color.withValues(alpha: color.a * p)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }

    // 3) Tagline.
    if (showTagline) {
      final p = _span(t, 0.78, 1.0, Curves.easeOut);
      if (p > 0) {
        canvas.drawPath(
          _tagline,
          Paint()
            ..color = taglineColor.withValues(alpha: taglineColor.a * p)
            ..isAntiAlias = true,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(final _LogoPainter old) =>
      old.color != color || old.taglineColor != taglineColor || old.showTagline != showTagline;
}
