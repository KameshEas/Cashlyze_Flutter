import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/budget.dart';
import '../../core/providers/budget_providers.dart';
import '../../core/utils/format.dart';
import '../../core/ui/constants.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import '../../core/widgets/animated_progress_text.dart';

class BudgetCard extends ConsumerStatefulWidget {
  final BudgetModel budget;
  final String currency;
  final bool isSynthetic;

  const BudgetCard({
    super.key,
    required this.budget,
    required this.currency,
    required this.isSynthetic,
  });

  @override
  ConsumerState<BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends ConsumerState<BudgetCard> {
  bool _showBack = false;

  void _toggle() {
    if (widget.isSynthetic) return;
    setState(() => _showBack = !_showBack);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allocated = widget.budget.allocated;
    final spent = ref.watch(
      budgetsUtilizationProvider.select((m) => m[widget.budget.id] ?? 0.0),
    );
    final progress = allocated.isFinite ? (allocated == 0 ? 0.0 : (spent / allocated)) : 0.0;
    final allocatedLabel = allocated.isFinite ? formatAmount(allocated, widget.currency) : '∞';
    final remaining = allocated.isFinite ? (allocated - spent) : double.infinity;

    return GestureDetector(
      onTap: _toggle,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _showBack ? math.pi : 0),
        duration: const Duration(milliseconds: 380),
        builder: (ctx, angle, child) {
          final isUnder = angle > (math.pi / 2);
          Widget face;
          if (isUnder) {
            face = Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: _buildBack(theme, remaining),
            );
          } else {
            face = _buildFront(theme, allocatedLabel, spent, progress);
          }
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: face,
          );
        },
      ),
    );
  }

  Widget _buildFront(ThemeData theme, String allocatedLabel, double spent, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.budget.name, style: theme.textTheme.titleMedium),
              Text('${formatAmount(spent, widget.currency)} / $allocatedLabel', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AnimatedProgressIndicator(
                  progress: progress.clamp(0.0, double.infinity),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              AnimatedProgressText(
                progress: progress.clamp(0.0, 1.0),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack(ThemeData theme, double remaining) {
    final remLabel = remaining.isFinite ? formatAmount(remaining, widget.currency) : '∞';
    final over = remaining.isFinite ? remaining < 0 : false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Remaining', style: theme.textTheme.titleSmall),
              Text(remLabel, style: theme.textTheme.titleMedium?.copyWith(color: over ? theme.colorScheme.error : null, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
