import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/utils/format.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthly = ref.watch(monthlyTrendProvider);
    final categories = ref.watch(categoryBreakdownProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final kpis = ref.watch(kpisProvider);
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insights',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('7d'),
                      selected: selectedRange == TimeRange.last7d,
                      onSelected: (_) => ref
                          .read(selectedTimeRangeProvider.notifier)
                          .setRange(TimeRange.last7d),
                    ),
                    ChoiceChip(
                      label: const Text('30d'),
                      selected: selectedRange == TimeRange.last30d,
                      onSelected: (_) => ref
                          .read(selectedTimeRangeProvider.notifier)
                          .setRange(TimeRange.last30d),
                    ),
                    ChoiceChip(
                      label: const Text('90d'),
                      selected: selectedRange == TimeRange.last90d,
                      onSelected: (_) => ref
                          .read(selectedTimeRangeProvider.notifier)
                          .setRange(TimeRange.last90d),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income', style: theme.textTheme.bodySmall),
                      Text(
                        formatAmount(kpis.income, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expense', style: theme.textTheme.bodySmall),
                      Text(
                        formatAmount(kpis.expense, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net', style: theme.textTheme.bodySmall),
                      Text(
                        formatAmount(kpis.net, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avg/day', style: theme.textTheme.bodySmall),
                      Text(
                        formatAmount(kpis.avgDailySpend, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Monthly Trend',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (txsAsync.isLoading)
              (MediaQuery.of(context).disableAnimations
                  ? Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _shimmer,
                      builder: (ctx, _) => Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.05,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.08 + 0.1 * _shimmer.value,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ))
            else if (monthly.isEmpty)
              Center(
                child: Column(
                  children: [
                    Semantics(
                      label: 'No trend data illustration',
                      child: Icon(
                        Icons.trending_up,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('No trend data', style: theme.textTheme.titleMedium),
                  ],
                ),
              )
            else
              Semantics(
                label:
                    'Monthly trend for selected range. Income ${kpis.income.toStringAsFixed(2)}, expense ${kpis.expense.toStringAsFixed(2)}, net ${kpis.net.toStringAsFixed(2)}.',
                child: Container(
                  height: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx > 5)
                                return const SizedBox.shrink();
                              final now = DateTime.now();
                              final m = DateTime(
                                now.year,
                                now.month - (5 - idx),
                                1,
                              );
                              final label = DateFormat('MMM').format(m);
                              return Text(
                                label,
                                style: theme.textTheme.bodySmall,
                              );
                            },
                            interval: 1,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            monthly.length,
                            (i) => FlSpot(i.toDouble(), monthly[i]),
                          ),
                          isCurved: true,
                          barWidth: 3,
                          color: theme.colorScheme.secondary,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Consumer(
              builder: (chipCtx, chipRef, _) {
                final catsAsync = chipRef.watch(userCategoriesProvider);
                final selected = chipRef.watch(selectedCategoriesProvider);
                return catsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (err, st) => const SizedBox.shrink(),
                  data: (list) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: selected.isEmpty,
                          onSelected: (_) => chipRef
                              .read(selectedCategoriesProvider.notifier)
                              .clear(),
                        ),
                        const SizedBox(width: 8),
                        ...list.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: selected.contains(c.name),
                              onSelected: (_) => chipRef
                                  .read(selectedCategoriesProvider.notifier)
                                  .toggle(c.name),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Text(
              'Spending by Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (txsAsync.isLoading)
              AnimatedBuilder(
                animation: _shimmer,
                builder: (ctx, _) => Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08 + 0.1 * _shimmer.value,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (categories.isEmpty)
              Center(
                child: Column(
                  children: [
                    Semantics(
                      label: 'No category data illustration',
                      child: Icon(
                        Icons.pie_chart_outline,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No category data',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add transactions to see insights',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        GoRouter.of(context).go('/transactions');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add transaction'),
                    ),
                  ],
                ),
              )
            else
              Semantics(
                label: 'Spending by category for selected range.',
                child: Container(
                  height: 240,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: categories.entries.map((e) {
                        final palette = [
                          theme.colorScheme.secondary,
                          theme.colorScheme.primary,
                          theme.colorScheme.error,
                          theme.colorScheme.secondaryContainer,
                          theme.colorScheme.primaryContainer,
                        ];
                        final idx = e.key.hashCode % palette.length;
                        final color = palette[idx];
                        return PieChartSectionData(
                          title: e.key,
                          value: e.value,
                          color: color,
                          titleStyle: theme.textTheme.bodySmall,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Semantics(
                label: 'Chart legend for categories',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.entries.map((e) {
                    final palette = [
                      theme.colorScheme.secondary,
                      theme.colorScheme.primary,
                      theme.colorScheme.error,
                      theme.colorScheme.secondaryContainer,
                      theme.colorScheme.primaryContainer,
                    ];
                    final idx = e.key.hashCode % palette.length;
                    final color = palette[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(e.key, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final recos = ref.watch(recommendationsProvider);
                if (recos.isEmpty) {
                  return Text(
                    'No suggestions for this range',
                    style: theme.textTheme.bodySmall,
                  );
                }
                return Column(
                  children: recos
                      .map(
                        (r) => ListTile(
                          leading: const Icon(Icons.lightbulb_outline),
                          title: Text(r),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Anomalies',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final anomalies = ref.watch(anomaliesProvider);
                if (anomalies.isEmpty) {
                  return Text(
                    'No anomalies detected in this range',
                    style: theme.textTheme.bodySmall,
                  );
                }
                return Column(
                  children: anomalies.take(5).map((t) {
                    final isIncome = t.amount >= 0;
                    return ListTile(
                      leading: Icon(
                        Icons.warning_amber_outlined,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(t.title),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.categoryId ?? 'Uncategorized',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${t.date.toLocal()}'.split('.').first,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        formatAmount(t.amount, currency),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isIncome
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
