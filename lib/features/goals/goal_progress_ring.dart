import 'package:flutter/material.dart';

class GoalProgressRing extends StatelessWidget {
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
  Widget build(final BuildContext context) {
    final progressValue = (progress / 100).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ProgressRingPainter(
              progress: progressValue,
              color: color,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${currentAmount.toStringAsFixed(0)} / ${targetAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: size * 0.12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
  });

  final double progress;
  final Color color;

  @override
  void paint(final Canvas canvas, final Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
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
    return oldDelegate.progress != progress;
  }
}
