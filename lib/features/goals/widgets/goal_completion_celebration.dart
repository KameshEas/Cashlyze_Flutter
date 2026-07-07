import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/ui/motion.dart';

/// A brief, one-shot celebration shown the first time a goal reaches 100%.
///
/// Plays a checkmark-burst Lottie animation over a translucent scrim and
/// dismisses itself automatically. Under reduce-motion, skips straight to a
/// static checkmark instead of animating.
class GoalCompletionCelebration extends StatefulWidget {
  const GoalCompletionCelebration({super.key});

  /// Shows the celebration as a self-dismissing dialog.
  static Future<void> show(final BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (final context) => const GoalCompletionCelebration(),
    );
  }

  @override
  State<GoalCompletionCelebration> createState() =>
      _GoalCompletionCelebrationState();
}

class _GoalCompletionCelebrationState extends State<GoalCompletionCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.slow,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleDismiss(final Duration holdAfterEnd) {
    Future.delayed(holdAfterEnd, () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(final BuildContext context) {
    final reduce = reduceMotionOf(context);

    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Lottie.asset(
          'assets/animations/goal_complete.json',
          controller: _controller,
          repeat: false,
          onLoaded: (final composition) {
            _controller.duration = composition.duration;
            if (reduce) {
              _controller.value = 1.0;
              _scheduleDismiss(const Duration(milliseconds: 900));
            } else {
              _controller.forward();
              _scheduleDismiss(
                composition.duration + const Duration(milliseconds: 300),
              );
            }
          },
        ),
      ),
    );
  }
}
