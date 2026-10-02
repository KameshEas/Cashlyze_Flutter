import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/constants.dart';

/// A looping "counting cash" loader: banknotes peel off the left bundle,
/// arc over, and land on the right bundle while a running ₹ total ticks up.
/// Replaces generic spinners on brand surfaces (splash / app-loading).
///
/// Drawn on a dark/brand background: notes are pale with teal detailing.
/// Honors reduced motion by holding a single static frame.
class CashCountLoader extends StatefulWidget {
  const CashCountLoader({
    super.key,
    this.width = 180,
    this.showCounter = true,
    this.currencySymbol = '₹',
    this.counterColor = Colors.white,
  });

  final double width;
  final bool showCounter;
  final String currencySymbol;
  final Color counterColor;

  @override
  State<CashCountLoader> createState() => _CashCountLoaderState();
}

class _CashCountLoaderState extends State<CashCountLoader> with SingleTickerProviderStateMixin {
  /// Notes counted per loop; the counter shows `noteValue` per landed note.
  static const _notesPerLoop = 8;
  static const _noteValue = 100;
  static const _loop = Duration(milliseconds: 5200);

  late final AnimationController _c = AnimationController(vsync: this, duration: _loop);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5; // one static, mid-flight frame
    } else {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final height = widget.width * 0.6;
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.width,
              height: height,
              child: CustomPaint(painter: _CashPainter(_c, _notesPerLoop)),
            ),
            if (widget.showCounter) ...[
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _c,
                builder: (final context, final _) {
                  final landed = (_c.value * _notesPerLoop).floor() + 1;
                  final total = landed * _noteValue;
                  return Text(
                    '${widget.currencySymbol} ${_group(total)}',
                    style: TextStyle(
                      color: widget.counterColor.withValues(alpha: 0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _group(final int n) {
    final s = n.toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }
}

class _CashPainter extends CustomPainter {
  _CashPainter(this.anim, this.notes) : super(repaint: anim);

  final Animation<double> anim;
  final int notes;

  static const _paper = Color(0xFFEAF6F7);

  @override
  void paint(final Canvas canvas, final Size size) {
    final w = size.width;
    final h = size.height;
    final noteW = w * 0.34;
    final noteH = noteW * 0.5;
    final baseY = h * 0.8;
    final leftX = w * 0.20;
    final rightX = w * 0.80;

    // Bundles: the source shrinks, the destination grows within each flight.
    final phase = (anim.value * notes) % 1.0;
    _bundle(canvas, Offset(leftX, baseY), noteW, noteH, 4);
    _bundle(canvas, Offset(rightX, baseY), noteW, noteH, 2 + (phase > 0.85 ? 1 : 0));

    // Two notes in flight, half a cycle apart, each on a parabola.
    for (var i = 0; i < 2; i++) {
      final t = (phase + i / 2) % 1.0;
      final eased = Curves.easeInOut.transform(t);
      final x = leftX + (rightX - leftX) * eased;
      final lift = math.sin(math.pi * t) * h * 0.3;
      final y = baseY - noteH * 0.9 - lift;
      // Notes tilt forward as they launch and flatten on landing.
      final angle = (0.5 - t) * 0.55;
      final alpha = (t < 0.1 ? t / 0.1 : (t > 0.92 ? (1 - t) / 0.08 : 1.0)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      _note(canvas, Offset.zero, noteW, noteH, alpha);
      canvas.restore();
    }
  }

  void _bundle(final Canvas canvas, final Offset base, final double nw, final double nh, final int layers) {
    for (var i = 0; i < layers; i++) {
      _note(canvas, Offset(base.dx, base.dy - i * 3.2), nw, nh, 1, flat: true);
    }
  }

  void _note(final Canvas canvas, final Offset c, final double nw, final double nh, final double alpha, {final bool flat = false}) {
    final rect = Rect.fromCenter(center: c, width: nw, height: nh);
    final r = RRect.fromRectAndRadius(rect, Radius.circular(nh * 0.16));
    canvas.drawRRect(r, Paint()..color = _paper.withValues(alpha: alpha));
    canvas.drawRRect(
      r.deflate(nh * 0.09),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.brandTeal.withValues(alpha: alpha * 0.7),
    );
    if (flat) return; // bundle layers only need the silhouette + frame
    canvas.drawCircle(c, nh * 0.26, Paint()..color = AppColors.brandTeal.withValues(alpha: alpha));
    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: nh * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    final line = Paint()
      ..color = AppColors.brandTeal.withValues(alpha: alpha * 0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - nw * 0.38, c.dy - nh * 0.22), Offset(c.dx - nw * 0.2, c.dy - nh * 0.22), line);
    canvas.drawLine(Offset(c.dx + nw * 0.2, c.dy + nh * 0.22), Offset(c.dx + nw * 0.38, c.dy + nh * 0.22), line);
  }

  @override
  bool shouldRepaint(final _CashPainter old) => old.notes != notes;
}
