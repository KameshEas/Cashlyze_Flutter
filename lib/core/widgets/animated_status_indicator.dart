import 'package:flutter/material.dart';

/// Animated status indicator widget that smoothly transitions budget status and color.
/// 
/// Uses AnimatedOpacity and AnimatedContainer to transition between status states
/// (Over Budget / Under Budget) with smooth color changes.
class AnimatedStatusIndicator extends StatefulWidget {

  const AnimatedStatusIndicator({
    super.key,
    required this.progress,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeInOut,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });
  final double progress;
  final Duration duration;
  final Curve curve;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  @override
  State<AnimatedStatusIndicator> createState() =>
      _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator> {
  @override
  void didUpdateWidget(final AnimatedStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  /// Gets the status text based on progress value.
  String _getStatusText(final double progress) {
    if (progress >= 1.0) {
      final overAmount = ((progress - 1.0) * 100).toStringAsFixed(0);
      return 'Over Budget (+$overAmount%)';
    }
    final remaining = ((1.0 - progress) * 100).toStringAsFixed(0);
    return 'Budget Available ($remaining%)';
  }

  /// Gets the background color based on progress.
  Color _getBackgroundColor(final double progress) {
    if (progress >= 1.0) {
      return Colors.red.withValues(alpha: 0.15);
    }
    if (progress >= 0.9) {
      return Colors.orange.withValues(alpha: 0.15);
    }
    return Colors.green.withValues(alpha: 0.15);
  }

  /// Gets the text color based on progress.
  Color _getTextColor(final double progress) {
    if (progress >= 1.0) {
      return Colors.red;
    }
    if (progress >= 0.9) {
      return Colors.orange;
    }
    return Colors.green;
  }

  @override
  Widget build(final BuildContext context) {
    final statusText = _getStatusText(widget.progress);
    final backgroundColor = _getBackgroundColor(widget.progress);
    final textColor = _getTextColor(widget.progress);

    return AnimatedContainer(
      duration: widget.duration,
      curve: widget.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius,
      ),
      child: AnimatedDefaultTextStyle(
        style: (widget.textStyle ?? const TextStyle()).copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        duration: widget.duration,
        curve: widget.curve,
        child: Text(statusText),
      ),
    );
  }
}
