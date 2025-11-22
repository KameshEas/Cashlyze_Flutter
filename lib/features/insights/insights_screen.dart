import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/transaction_providers.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (txsAsync.isLoading)
              AnimatedBuilder(
                animation: _shimmer,
                builder: (ctx, _) => Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08 + 0.1 * _shimmer.value),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (monthly.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.trending_up, size: 72, color: theme.colorScheme.primary),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                          const labels = ['M-5', 'M-4', 'M-3', 'M-2', 'M-1', 'Now'];
                          if (idx >= 0 && idx < labels.length) {
                            return Text(labels[idx], style: theme.textTheme.bodySmall);
                          }
                          return const SizedBox.shrink();
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(monthly.length, (i) => FlSpot(i.toDouble(), monthly[i])),
                      isCurved: true,
                      barWidth: 3,
                      color: theme.colorScheme.secondary,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Spending by Category', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (txsAsync.isLoading)
              AnimatedBuilder(
                animation: _shimmer,
                builder: (ctx, _) => Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08 + 0.1 * _shimmer.value),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (categories.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 72, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('No category data', style: theme.textTheme.titleMedium),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
          ],
        ),
      ),
    );
  }
}