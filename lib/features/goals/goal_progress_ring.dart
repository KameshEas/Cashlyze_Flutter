import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';

class GoalProgressRing extends ConsumerWidget {
  const GoalProgressRing({
    required this.progress,
    required this.currentAmount,
    required this.targetAmount,
    this.size = 120,
    this.color = Colors.blue,
    super.key,
  });

  final double progress;
  final double currentAmount;
  final double targetAmount;
  final double size;
  final Color color;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final progressValue = (progress / 100).clamp(0.0, 1.0);
    final reduce = reduceMotionOf(context);
    final trackColor = theme.colorScheme.onSurface.withValues(alpha: 0.12);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progressValue),
            duration: reduce ? Duration.zero : AppDuration.slow,
            curve: AppCurve.decelerate,
            builder: (final context, final value, final child) => CustomPaint(
              size: Size(size, size),
              painter: _ProgressRingPainter(
                progress: value,
                color: color,
                trackColor: trackColor,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${progress.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: size * 0.25,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${formatAmount(currentAmount, currency)} / ${formatAmount(targetAmount, currency)}',
                  style: TextStyle(
                    fontSize: size * 0.12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(final Canvas canvas, final Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final backgroundPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = (2 * 3.14159 * progress);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(final _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
