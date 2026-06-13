import 'package:flutter/material.dart';

/// Calendar-based period picker for budget filtering
class PeriodPicker extends StatefulWidget {
  final String selectedPeriod;
  final ValueChanged<String> onPeriodChanged;

  const PeriodPicker({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  State<PeriodPicker> createState() => _PeriodPickerState();
}

class _PeriodPickerState extends State<PeriodPicker> {
  late String _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.selectedPeriod;
  }

  void _showPeriodMenu() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (final context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Period',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildPeriodOption(
                  'All Budgets',
                  'View budgets from all periods',
                  'All',
                  Icons.calendar_month,
                  colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _buildPeriodOption(
                  'Daily',
                  'Day-by-day budgets',
                  'Daily',
                  Icons.today,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildPeriodOption(
                  'Weekly',
                  'Week-by-week budgets',
                  'Weekly',
                  Icons.date_range,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildPeriodOption(
                  'Monthly',
                  'Month-by-month budgets',
                  'Monthly',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPeriodOption(
    final String title,
    final String subtitle,
    final String value,
    final IconData icon,
    final Color color,
  ) {
    final isSelected = _selectedPeriod == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedPeriod = value);
          widget.onPeriodChanged(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Period',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showPeriodMenu,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                color: theme.colorScheme.surface,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getPeriodIcon(_selectedPeriod),
                        size: 20,
                        color: _getPeriodColor(_selectedPeriod),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _selectedPeriod,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getPeriodIcon(final String period) {
    return switch (period) {
      'All' => Icons.calendar_month,
      'Daily' => Icons.today,
      'Weekly' => Icons.date_range,
      'Monthly' => Icons.calendar_today,
      _ => Icons.calendar_month,
    };
  }

  Color _getPeriodColor(final String period) {
    return switch (period) {
      'All' => Theme.of(context).colorScheme.primary,
      'Daily' => Colors.green,
      'Weekly' => Colors.orange,
      'Monthly' => Colors.blue,
      _ => Theme.of(context).colorScheme.primary,
    };
  }
}
