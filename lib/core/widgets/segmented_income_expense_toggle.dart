import 'package:flutter/material.dart';

import '../ui/constants.dart';
import '../ui/motion.dart';

/// A two-way segmented control for Expense / Income on the add/edit
/// transaction form.
///
/// Deliberately neutral: the selected segment is a raised, hairline-bordered
/// surface with strong text, not a red or green fill. The kind is stated by
/// the label and the direction arrow, so it never relies on colour, and red
/// stays reserved for errors and overspend.
class SegmentedIncomeExpenseToggle extends StatelessWidget {
  const SegmentedIncomeExpenseToggle({
    super.key,
    required this.isIncome,
    required this.onChanged,
    this.incomeLabel = 'Income',
    this.expenseLabel = 'Expense',
  });

  final bool isIncome;
  final ValueChanged<bool> onChanged;
  final String incomeLabel;
  final String expenseLabel;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: expenseLabel,
              icon: Icons.north_east_rounded,
              selected: !isIncome,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: incomeLabel,
              icon: Icons.south_west_rounded,
              selected: isIncome,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: reduceMotionOf(context) ? Duration.zero : const Duration(milliseconds: 160),
          height: AppSpacing.buttonHeight - AppSpacing.s8,
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: selected ? scheme.outline : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
