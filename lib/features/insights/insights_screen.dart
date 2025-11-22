import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/insights_providers.dart';

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income', style: theme.textTheme.bodySmall),
                      Text(
                        kpis.income.toStringAsFixed(2),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expense', style: theme.textTheme.bodySmall),
                      Text(
                        kpis.expense.toStringAsFixed(2),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net', style: theme.textTheme.bodySmall),
                      Text(
                        kpis.net.toStringAsFixed(2),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Avg/day', style: theme.textTheme.bodySmall),
                      Text(
                        kpis.avgDailySpend.toStringAsFixed(2),
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
              AnimatedBuilder(
                animation: _shimmer,
                builder: (ctx, _) => Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.08 + 0.1 * _shimmer.value,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (monthly.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text('No trend data', style: theme.textTheme.titleMedium),
                  ],
                ),
              )
            else
              Container(
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
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
                            const labels = [
                              'M-5',
                              'M-4',
                              'M-3',
                              'M-2',
                              'M-1',
                              'Now',
                            ];
                            if (idx >= 0 && idx < labels.length) {
                              return Text(
                                labels[idx],
                                style: theme.textTheme.bodySmall,
                              );
                            }
                            return const SizedBox.shrink();
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
            const SizedBox(height: 24),
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
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
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
                    Icon(
                      Icons.pie_chart_outline,
                      size: 72,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No category data',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: categories.entries.map((e) {
                      final color = e.key == 'Food'
                          ? Colors.tealAccent
                          : e.key == 'Transport'
                          ? Colors.orangeAccent
                          : e.key == 'Entertainment'
                          ? Colors.purpleAccent
                          : Colors.blueAccent;
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
                  children: anomalies
                      .take(5)
                      .map(
                        (t) => ListTile(
                          leading: const Icon(
                            Icons.warning_amber_outlined,
                            color: Colors.orange,
                          ),
                          title: Text(t.title),
                          subtitle: Text(
                            '${t.categoryId ?? 'Uncategorized'} • ${t.date.toLocal()}'
                                .split('.')
                                .first,
                          ),
                          trailing: Text(
                            '-${t.amount.abs().toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
