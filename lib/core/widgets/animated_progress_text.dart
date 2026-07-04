import 'package:flutter/material.dart';

/// Animated progress percentage text widget that smoothly transitions percentage values.
/// 
/// Uses TweenAnimationBuilder to animate numeric percentage display,
/// creating smooth transitions as budget progress changes.
class AnimatedProgressText extends StatefulWidget {

  const AnimatedProgressText({
    super.key,
    required this.progress,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
    this.suffix = '%',
  });
  final double progress;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final String suffix;

  @override
  State<AnimatedProgressText> createState() => _AnimatedProgressTextState();
}

class _AnimatedProgressTextState extends State<AnimatedProgressText> {
  late double _lastProgress;

  @override
  void initState() {
    super.initState();
    _lastProgress = widget.progress;
  }

  @override
  void didUpdateWidget(final AnimatedProgressText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _lastProgress = oldWidget.progress;
    }
  }

  /// Gets the color based on progress value for visual feedback.
  Color _getTextColor(final double progress) {
    final displayPercent = (progress * 100).clamp(0, double.infinity);
    
    if (displayPercent >= 100) {
      return Colors.red; // Over budget
    }
    if (displayPercent >= 90) {
      return Colors.orange; // Warning
    }
    return Colors.green; // Under budget
  }

  @override
  Widget build(final BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _lastProgress,
        end: widget.progress,
      ),
      duration: widget.duration,
      curve: widget.curve,
      builder: (final BuildContext context, final double animatedProgress, final Widget? child) {
        final displayPercent = (animatedProgress * 100).clamp(0, double.infinity);
        final textColor = _getTextColor(widget.progress);

        return AnimatedDefaultTextStyle(
          style: (widget.style ?? const TextStyle()).copyWith(
            color: textColor,
          ),
          duration: widget.duration,
          curve: widget.curve,
          child: Text(
            '${displayPercent.toStringAsFixed(0)}${widget.suffix}',
          ),
        );
      },
    );
  }
}
