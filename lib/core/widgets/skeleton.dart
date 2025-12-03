import 'package:flutter/material.dart';

class SkeletonLine extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const SkeletonLine({super.key, required this.height, required this.width, this.borderRadius = const BorderRadius.all(Radius.circular(6))});

  @override
  State<SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<SkeletonLine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TickerMode(
      enabled: !reduceMotion,
      child: reduceMotion
          ? Container(
              height: widget.height,
              width: widget.width,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: widget.borderRadius,
              ),
            )
          : AnimatedBuilder(
              animation: _anim,
              builder: (ctx, _) => Container(
                height: widget.height,
                width: widget.width,
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: 0.08 + 0.12 * _anim.value),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: const [
          SkeletonLine(height: 40, width: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLine(height: 14, width: double.infinity),
                SizedBox(height: 8),
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
  final double height;
  const SkeletonChartBox({super.key, required this.height});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const SkeletonLine(height: double.infinity, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(12))),
    );
  }
}
