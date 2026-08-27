import 'package:flutter/material.dart';

import '../ui/constants.dart';
import '../ui/motion.dart';

/// A two-way pill toggle for Income/Expense, replacing a plain dropdown on
/// the add/edit transaction form. Income uses the success/secondary tone,
/// Expense uses the error tone, so the selected state doubles as a visual
/// confirmation of which kind of transaction is being entered.
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
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: expenseLabel,
              icon: Icons.arrow_upward_rounded,
              selected: !isIncome,
              color: theme.colorScheme.error,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: incomeLabel,
              icon: Icons.arrow_downward_rounded,
              selected: isIncome,
              color: AppColors.success,
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
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onTap: onTap,
      child: MotionSwitcher(
        child: Container(
          key: ValueKey(selected),
          height: AppSpacing.buttonHeight - AppSpacing.s8,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: AppRadius.smAll,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: AppSpacing.s4 + 2),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
