import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/ui/constants.dart';
import '../../l10n/app_localizations.dart';

// Converted from ConsumerStatefulWidget → ConsumerWidget.
// The custom AnimationController was only used for a shimmer that duplicated
// SkeletonChartBox. Removing it eliminates ~40 lines of boilerplate.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthly = ref.watch(monthlyTrendProvider);
    final categories = ref.watch(categoryBreakdownProvider);
    final t = AppLocalizations.of(context);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final kpis = ref.watch(kpisProvider);
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final currency = ref.watch(currencyProvider);
    final isLoading = txsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Time-range selector ──────────────────────────────────────
            // Replaced Wrap(ChoiceChip) with SegmentedButton:
            //  • single widget, no stray padding, keyboard accessible
            //  • selection is immediately obvious via fill, not just border
            Semantics(
              label: 'Time range selector',
              child: SegmentedButton<TimeRange>(
                segments: const [
                  ButtonSegment(value: TimeRange.last7d, label: Text('7 days')),
                  ButtonSegment(
                    value: TimeRange.last30d,
                    label: Text('30 days'),
                  ),
                  ButtonSegment(
                    value: TimeRange.last90d,
                    label: Text('90 days'),
                  ),
                ],
                selected: {selectedRange},
                onSelectionChanged: (s) => ref
                    .read(selectedTimeRangeProvider.notifier)
                    .setRange(s.first),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // ── KPI summary card ─────────────────────────────────────────
            // Labels promoted from bodySmall → labelLarge for legibility.
            // Amounts use titleLarge + semantic colours:
            //   income = success green, expense = error red, net = primary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.lgAll,
                border: Border.all(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _KpiCell(
                    label: t?.income ?? 'Income',
                    amount: formatAmount(kpis.income, currency),
                    amountColor: AppColors.success,
                    icon: Icons.arrow_downward_rounded,
                    isLoading: isLoading,
                  ),
                  _VerticalDivider(),
                  _KpiCell(
                    label: t?.expense ?? 'Expense',
                    amount: formatAmount(kpis.expense, currency),
                    amountColor: AppColors.error,
                    icon: Icons.arrow_upward_rounded,
                    isLoading: isLoading,
                  ),
                  _VerticalDivider(),
                  _KpiCell(
                    label: t?.net ?? 'Net',
                    amount: formatAmount(kpis.net, currency),
                    amountColor: kpis.net >= 0
                        ? AppColors.success
                        : AppColors.error,
                    icon: Icons.account_balance_outlined,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Monthly trend chart ──────────────────────────────────────
            _SectionHeader(title: 'Monthly Trend'),
            const SizedBox(height: AppSpacing.s12),
            if (isLoading)
              const SkeletonChartBox(height: 220)
            else if (monthly.isEmpty)
              _EmptyChart(message: 'No trend data yet')
            else
              Semantics(
                label:
                    'Monthly trend chart. Income ${kpis.income.toStringAsFixed(2)}, '
                    'expense ${kpis.expense.toStringAsFixed(2)}, net ${kpis.net.toStringAsFixed(2)}.',
                child: _ChartCard(
                  height: 220,
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
                              return Text(
                                DateFormat('MMM').format(m),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
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
                          color: theme.colorScheme.primary,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sectionGap),

            // ── Category breakdown chart ─────────────────────────────────
            _SectionHeader(title: 'Spending by Category'),
            const SizedBox(height: AppSpacing.s12),
            if (isLoading)
              const SkeletonChartBox(height: 260)
            else if (categories.isEmpty)
              _EmptyChart(message: 'No category data yet')
            else
              Semantics(
                label: 'Spending by category for selected range.',
                child: _ChartCard(
                  height: 260,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 44,
                            sections: _buildPieSections(
                              context,
                              categories,
                              theme,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _CategoryLegend(
                          categories: categories,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.s16),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static const List<Color> _palette = [
    AppColors.emerald600,
    AppColors.teal500,
    AppColors.info,
    AppColors.warning,
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
  ];

  List<PieChartSectionData> _buildPieSections(
    BuildContext context,
    Map<String, double> categories,
    ThemeData theme,
  ) {
    int i = 0;
    return categories.entries.map((e) {
      final color = _palette[i % _palette.length];
      i++;
      return PieChartSectionData(
        title: '',  // labels moved to legend — avoids crowded chart text
        value: e.value,
        color: color,
        radius: 52,
      );
    }).toList();
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final double height;
  final Widget child;
  const _ChartCard({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: child,
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single KPI metric cell used in the summary row.
class _KpiCell extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;
  final IconData icon;
  final bool isLoading;

  const _KpiCell({
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.icon,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon badge
        Container(
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(
            color: amountColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: amountColor),
        ),
        const SizedBox(height: AppSpacing.s8),
        // Label
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        // Amount — was titleMedium, promoted to titleLarge + colour
        isLoading
            ? const SkeletonLine(height: 16, width: 72)
            : Text(
                amount,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 64,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    );
  }
}

/// Legend for the pie chart — labels moved here so pie slices stay clean.
class _CategoryLegend extends StatelessWidget {
  final Map<String, double> categories;
  final ThemeData theme;

  const _CategoryLegend({required this.categories, required this.theme});

  static const List<Color> _palette = [
    AppColors.emerald600,
    AppColors.teal500,
    AppColors.info,
    AppColors.warning,
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final total = categories.values.fold(0.0, (a, b) => a + b);
    int i = 0;
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.entries.map((e) {
          final color = _palette[i % _palette.length];
          final pct = total > 0 ? (e.value / total * 100) : 0;
          i++;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    e.key,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

