import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/utils/format.dart';
import '../../l10n/app_localizations.dart';

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
    // final filtered = ref.watch(filteredTransactionsProvider);
    final categories = ref.watch(categoryBreakdownProvider);
    final t = AppLocalizations.of(context);
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
                      Text(
                        t?.income ?? 'Income',
                        style: theme.textTheme.bodySmall,
                      ),

                      Text(
                        formatAmount(kpis.income, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t?.expense ?? 'Expense',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        formatAmount(kpis.expense, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t?.net ?? 'Net', style: theme.textTheme.bodySmall),
                      Text(
                        formatAmount(kpis.net, currency),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final reduceMotion = MediaQuery.of(ctx).disableAnimations;
                final duration = reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180);
                Widget child;
                if (txsAsync.isLoading) {
                  child = MediaQuery.of(context).disableAnimations
                      ? Container(
                          key: const ValueKey('trend_static'),
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
                          key: const ValueKey('trend_shimmer'),
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
                        );
                } else if (monthly.isEmpty) {
                  child = Center(
                    key: const ValueKey('trend_empty'),
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
                        Text(
                          'No trend data',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                } else {
                  child = Semantics(
                    key: const ValueKey('trend_chart'),
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
                                  if (idx < 0 || idx > 5) {
                                    return const SizedBox.shrink();
                                  }
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
                  );
                }
                return AnimatedSwitcher(duration: duration, child: child);
              },
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final reduceMotion = MediaQuery.of(ctx).disableAnimations;
                final duration = reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180);
                Widget child = const SizedBox.shrink();
                if (txsAsync.isLoading) {
                  child = MediaQuery.of(context).disableAnimations
                      ? Container(
                          key: const ValueKey('cat_static'),
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
                        )
                      : AnimatedBuilder(
                          key: const ValueKey('cat_shimmer'),
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
                        );
                } else if (categories.isNotEmpty) {
                  child = Semantics(
                    key: const ValueKey('cat_chart'),
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
                  );
                }
                return AnimatedSwitcher(duration: duration, child: child);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
