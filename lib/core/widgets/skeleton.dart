import 'package:flutter/material.dart';
import '../ui/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton shimmer colour helpers
// Uses onSurface so it reads correctly on BOTH light and dark backgrounds.
// Light mode: dark-on-light shimmer  (onSurface = black)
// Dark mode : light-on-dark shimmer  (onSurface = white)
// ─────────────────────────────────────────────────────────────────────────────
Color _shimmerColor(final BuildContext context, final double opacity) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);

class SkeletonLine extends StatefulWidget {
  const SkeletonLine({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.sm)),
  });
  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  State<SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TickerMode(
      enabled: !reduceMotion,
      child: reduceMotion
          ? Container(
              height: widget.height,
              width: widget.width,
              decoration: BoxDecoration(
                // Theme-adaptive: visible on both light and dark
                color: _shimmerColor(context, 0.10),
                borderRadius: widget.borderRadius,
              ),
            )
          : AnimatedBuilder(
              animation: _anim,
              builder: (final ctx, _) => Container(
                height: widget.height,
                width: widget.width,
                decoration: BoxDecoration(
                  // Pulses between 6 % and 14 % opacity — visible on both modes
                  color: _shimmerColor(context, 0.06 + 0.08 * _anim.value),
                  borderRadius: widget.borderRadius,
                ),
              ),
            ),
    );
  }
}

class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: borderColor),
      ),
      child: const Row(
        children: [
          SkeletonLine(
            height: 40,
            width: 40,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
          ),
          SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(height: 14, width: double.infinity),
                SizedBox(height: AppSpacing.s8),
                SkeletonLine(height: 12, width: 160),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonChartBox extends StatelessWidget {
  const SkeletonChartBox({super.key, required this.height});
  final double height;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: borderColor),
      ),
      child: const SkeletonLine(
        height: double.infinity,
        width: double.infinity,
        borderRadius: AppRadius.mdAll,
      ),
    );
  }
}
