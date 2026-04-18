import 'package:flutter/material.dart';

/// Animated progress indicator that smoothly transitions progress value and color changes.
/// 
/// Uses TweenAnimationBuilder to animate the progress value from 0.0-1.0 (and beyond),
/// and AnimatedOpacity to smoothly transition between colors based on budget status.
class AnimatedProgressIndicator extends StatefulWidget {
  final double progress;
  final double minHeight;
  final Duration duration;
  final BorderRadiusGeometry borderRadius;
  final Color? backgroundColor;
  final Curve curve;

  const AnimatedProgressIndicator({
    super.key,
    required this.progress,
    this.minHeight = 8.0,
    this.duration = const Duration(milliseconds: 500),
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.backgroundColor,
    this.curve = Curves.easeInOut,
  });

  @override
  State<AnimatedProgressIndicator> createState() =>
      _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator> {
  late double _lastProgress;

  @override
  void initState() {
    super.initState();
    _lastProgress = widget.progress.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _lastProgress = oldWidget.progress.clamp(0.0, 1.0);
    }
  }

  /// Determines the color based on progress value.
  /// Green (under budget) when progress < 1.0
  /// Red (over budget) when progress >= 1.0
  Color _getProgressColor(double progress) {
    if (progress >= 1.0) {
      return Colors.red; // Over budget
    }
    if (progress >= 0.9) {
      return Colors.orange; // Warning: approaching limit
    }
    return Colors.green; // Under budget
  }

  @override
  Widget build(BuildContext context) {
    final clampedProgress = widget.progress.clamp(0.0, 1.0);
    final progressColor = _getProgressColor(widget.progress);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _lastProgress,
        end: clampedProgress,
      ),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, animatedProgress, child) {
        return AnimatedOpacity(
          opacity: 1.0,
          duration: widget.duration,
          curve: widget.curve,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: LinearProgressIndicator(
              value: animatedProgress,
              minHeight: widget.minHeight,
              backgroundColor: widget.backgroundColor ?? Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        );
      },
    );
  }
}
