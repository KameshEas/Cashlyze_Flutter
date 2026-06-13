import 'package:flutter/material.dart';
import '../../../core/utils/format.dart';

/// Spending trend visualization for budget analysis
class SpendingTrendChart extends StatelessWidget {
  final String budgetName;
  final double allocated;
  final double spent;
  final String currency;
  final List<SpendingDataPoint> trendData;

  const SpendingTrendChart({
    super.key,
    required this.budgetName,
    required this.allocated,
    required this.spent,
    required this.currency,
    required this.trendData,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final progress = allocated == 0 ? 0.0 : (spent / allocated).clamp(0.0, 1.0);
    final remaining = (allocated - spent).clamp(0.0, allocated);
    final isOverBudget = spent > allocated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budgetName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Spending Trend',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverBudget
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOverBudget ? 'Over Budget' : 'On Track',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.outline.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ${formatAmount(spent, currency)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Budget: ${formatAmount(allocated, currency)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trend chart
          if (trendData.isNotEmpty) ...[
            Text(
              'Trend',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            _buildMiniChart(context, trendData),
            const SizedBox(height: 12),
          ],

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Remaining',
                  formatAmount(remaining.clamp(0.0, allocated), currency),
                  isOverBudget ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Used',
                  '${(progress * 100).toStringAsFixed(0)}%',
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart(
    final BuildContext context,
    final List<SpendingDataPoint> data,
  ) {
    final theme = Theme.of(context);
    final maxValue = data.fold<double>(0, (max, point) => point.value > max ? point.value : max);

    return SizedBox(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((final entry) {
          final point = entry.value;
          final normalizedHeight = maxValue > 0 ? (point.value / maxValue) : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: double.infinity,
                    height: (normalizedHeight * 50).clamp(4, 50).toDouble(),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.3 + (normalizedHeight * 0.7),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 8,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatItem(
    final BuildContext context,
    final String label,
    final String value,
    final Color accentColor,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data point for spending trend
class SpendingDataPoint {
  final String label;
  final double value;

  const SpendingDataPoint({
    required this.label,
    required this.value,
  });
}
