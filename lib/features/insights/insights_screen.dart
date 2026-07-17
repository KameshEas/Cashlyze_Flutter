import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/budget_analytics_providers.dart';
import '../../core/providers/export_service_provider.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/animated_progress_indicator.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';

const List<Color> _kPalette = [
  AppColors.emerald600,
  AppColors.teal500,
  AppColors.info,
  AppColors.warning,
  AppColors.chartViolet,
  AppColors.chartPink,
];

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  Future<void> _exportInsights(
    final BuildContext context,
    final WidgetRef ref,
    final AsyncValue<Map<String, double>> categoryBreakdownAsync,
    final Kpis kpis,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final currency = ref.read(currencyProvider);

    try {
      final breakdown = categoryBreakdownAsync.maybeWhen(
        data: (final data) => data,
        orElse: () => <String, double>{},
      );

      if (breakdown.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No category data to export')),
        );
        return;
      }

      final exportService = ref.read(exportServiceProvider);
      final file = await exportService.generateInsightsPDF(
        breakdown,
        kpis.income.toDouble(),
        kpis.expense.toDouble(),
        kpis.net.toDouble(),
        currency,
      );
      await Share.shareXFiles([XFile(file.path)], text: 'Insights report');
    } catch (e) {
      showRepoErrorSnackBar(messenger, e);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final txsAsync = ref.watch(recentTransactionsProvider);
    final kpis = ref.watch(kpisProvider);
    final monthly = ref.watch(monthlyTrendProvider);
    final categoryBreakdownAsync = ref.watch(serverCategoryBreakdownProvider);

    final topMerchants = ref.watch(topMerchantsProvider);
    final recurring = ref.watch(recurringPaymentsProvider);
    final anomalies = ref.watch(anomaliesProvider);
    final forecast = ref.watch(forecastExpenseNextMonthProvider);
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final currency = ref.watch(currencyProvider);
    final isLoading = txsAsync.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export insights',
            icon: const Icon(Icons.download),
            onPressed: () =>
                _exportInsights(context, ref, categoryBreakdownAsync, kpis),
          ),
          _TimeRangePicker(
            selected: selectedRange,
            onChanged: (final r) =>
                ref.read(selectedTimeRangeProvider.notifier).setRange(r),
          ),
          const SizedBox(width: AppSpacing.s16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentTransactionsProvider);
          await ref.read(recentTransactionsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            0,
            AppSpacing.pagePadding,
            AppSpacing.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (txsAsync.hasError) ...[
                const SizedBox(height: AppSpacing.s12),
                AppEmptyState(
                  title: 'Failed to load your latest transactions',
                  subtitle: repoErrorMessage(txsAsync.error ?? 'Unknown error'),
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(recentTransactionsProvider),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],
              // ── Net balance hero ───────────────────────────────────────────
              _NetHeroCard(
                kpis: kpis,
                currency: currency,
                isLoading: isLoading,
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── 4-metric strip ─────────────────────────────────────────────
              _MetricStrip(
                kpis: kpis,
                currency: currency,
                isLoading: isLoading,
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Forecast card ──────────────────────────────────────────────
              if (!isLoading && forecast != null) ...[
                _ForecastCard(
                  forecast: forecast,
                  monthly: monthly,
                  currency: currency,
                ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],

              // ── Monthly trend ──────────────────────────────────────────────
              const _SectionHeader(
                title: 'Monthly Trend',
                icon: Icons.show_chart_rounded,
              ),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 200)
              else if (monthly.isEmpty)
                const AppEmptyState(
                  title: 'No trend data',
                  subtitle: 'Add transactions to see your monthly trend',
                  icon: Icons.show_chart_rounded,
                )
              else
                _MonthlyTrendCard(monthly: monthly),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Category Breakdown ──────────────────────────────────────
              const _SectionHeader(
                title: 'Category Breakdown',
                icon: Icons.pie_chart_rounded,
              ),
              const SizedBox(height: AppSpacing.s12),
              categoryBreakdownAsync.when(
                loading: () => const SkeletonChartBox(height: 240),
                error: (final err, final stack) => const AppEmptyState(
                  title: 'Failed to load category data',
                  subtitle: 'Unable to fetch category breakdown from server',
                  icon: Icons.pie_chart_rounded,
                ),
                data: (final breakdown) {
                  if (breakdown.isEmpty) {
                    return const AppEmptyState(
                      title: 'No category data',
                      subtitle: 'Add transactions to see category breakdown',
                      icon: Icons.pie_chart_rounded,
                    );
                  }
                  return _CategoryBreakdownCard(
                    breakdown: breakdown,
                    currency: currency,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Top Spends ──────────────────────────────────────────────
              const _SectionHeader(
                title: 'Top Spends',
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 180)
              else if (topMerchants.isEmpty)
                const AppEmptyState(
                  title: 'No merchant data',
                  subtitle: 'No merchant data for this period',
                  icon: Icons.storefront_rounded,
                )
              else
                _MerchantsCard(merchants: topMerchants, currency: currency),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Recurring payments ─────────────────────────────────────────
              const _SectionHeader(
                title: 'Recurring Payments',
                icon: Icons.repeat_rounded,
              ),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 140)
              else if (recurring.isEmpty)
                const AppEmptyState(
                  title: 'No recurring payments',
                  subtitle: 'No recurring payments detected yet',
                  icon: Icons.repeat_rounded,
                )
              else
                _RecurringCard(recurring: recurring, currency: currency),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Unusual activity ───────────────────────────────────────────
              if (!isLoading && anomalies.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Unusual Activity',
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: AppSpacing.s12),
                _AnomalyCard(anomalies: anomalies, currency: currency),
                const SizedBox(height: AppSpacing.sectionGap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared primitives
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 17, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.s8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
  }
}

// _EmptyState removed in favor of shared AppEmptyState widget.

// ════════════════════════════════════════════════════════════════════════════
// Time range picker
// ════════════════════════════════════════════════════════════════════════════

class _TimeRangePicker extends StatelessWidget {
  const _TimeRangePicker({required this.selected, required this.onChanged});
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeRange.values.map((final r) {
          final label = switch (r) {
            TimeRange.last7d => '7d',
            TimeRange.last30d => '30d',
            TimeRange.last90d => '90d',
          };
          final isSelected = r == selected;
          return GestureDetector(
            onTap: () => onChanged(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Net balance hero card
// ════════════════════════════════════════════════════════════════════════════

class _NetHeroCard extends StatelessWidget {
  const _NetHeroCard({
    required this.kpis,
    required this.currency,
    required this.isLoading,
  });
  final Kpis kpis;
  final String currency;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = kpis.net >= 0;
    final netColor = isPositive ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            netColor.withValues(alpha: 0.13),
            netColor.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: netColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net Balance',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (isLoading)
            const SkeletonLine(height: 32, width: 160)
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatAmount(kpis.net.abs(), currency),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: netColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.14),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: netColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPositive ? 'Surplus' : 'Deficit',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: netColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 4-metric strip: Income | Expense | Savings % | Daily avg
// ════════════════════════════════════════════════════════════════════════════

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.kpis,
    required this.currency,
    required this.isLoading,
  });
  final Kpis kpis;
  final String currency;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final savingsPct = (kpis.savingsRate * 100).clamp(0, 100);
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.arrow_downward_rounded,
            color: AppColors.success,
            label: 'Income',
            value: isLoading ? null : formatAmount(kpis.income, currency),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: _MetricTile(
            icon: Icons.arrow_upward_rounded,
            color: AppColors.error,
            label: 'Expenses',
            value: isLoading ? null : formatAmount(kpis.expense, currency),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: _MetricTile(
            icon: Icons.savings_outlined,
            color: AppColors.info,
            label: 'Savings',
            value: isLoading ? null : '${savingsPct.toStringAsFixed(1)}%',
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: _MetricTile(
            icon: Icons.today_rounded,
            color: AppColors.warning,
            label: 'Daily avg',
            value: isLoading
                ? null
                : formatAmount(kpis.avgDailySpend, currency),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  // null = loading
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: AppSpacing.s4),
          value == null
              ? const SkeletonLine(height: 13, width: 40)
              : Text(
                  value!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Forecast card
// ════════════════════════════════════════════════════════════════════════════

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({
    required this.forecast,
    required this.monthly,
    required this.currency,
  });
  final double forecast;
  final List<double> monthly;
  final String currency;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final lastMonth = monthly.isNotEmpty ? monthly.last : forecast;
    final diff = forecast - lastMonth;
    final pct = lastMonth != 0 ? (diff / lastMonth * 100) : 0.0;
    final isUp = diff > 0;
    final changeColor = isUp ? AppColors.error : AppColors.success;

    return _BaseCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.10),
              borderRadius: AppRadius.mdAll,
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.info,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forecast — Next Month',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  formatAmount(forecast, currency),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: changeColor.withValues(alpha: 0.10),
              borderRadius: AppRadius.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 12,
                  color: changeColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${pct.abs().toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Monthly trend chart
// ════════════════════════════════════════════════════════════════════════════

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.monthly});
  final List<double> monthly;

  String get _trendSummary {
    if (monthly.length < 2) return 'Monthly spending trend chart';
    final first = monthly.first;
    final last = monthly.last;
    final direction = last > first
        ? 'increasing'
        : last < first
        ? 'decreasing'
        : 'flat';
    return 'Monthly spending trend chart, $direction over the last ${monthly.length} months';
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return _BaseCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s8,
      ),
      child: Semantics(
        label: _trendSummary,
        child: SizedBox(
          height: 200,
          child: ExcludeSemantics(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (final value, final _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= monthly.length) {
                          return const SizedBox.shrink();
                        }
                        final now = DateTime.now();
                        final offset = monthly.length - 1 - idx;
                        final m = DateTime(now.year, now.month - offset);
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('MMM').format(m),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (final spots) => spots
                        .map(
                          (final s) => LineTooltipItem(
                            s.y.toStringAsFixed(0),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      monthly.length,
                      (final i) => FlSpot(i.toDouble(), monthly[i]),
                    ),
                    isCurved: true,
                    barWidth: 2.5,
                    color: color,
                    dotData: FlDotData(
                      getDotPainter:
                          (final spot, final _, final bar, final i) =>
                              FlDotCirclePainter(
                                radius: 3.5,
                                color: color,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.20),
                          color.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Category breakdown pie chart
// ════════════════════════════════════════════════════════════════════════════

class _CategoryBreakdownCard extends ConsumerWidget {
  const _CategoryBreakdownCard({
    required this.breakdown,
    required this.currency,
  });

  final Map<String, double> breakdown;
  final String currency;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final cats = ref
        .watch(userCategoriesProvider)
        .maybeWhen(data: (final d) => d, orElse: () => const <CategoryModel>[]);
    final catById = <String, String>{};
    for (final c in cats) {
      catById[c.id] = c.name;
    }

    final sorted = breakdown.entries.toList()
      ..sort((final a, final b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final total = sorted.fold<double>(0, (final sum, final e) => sum + e.value);

    final sections = List.generate(top.length, (final i) {
      final entry = top[i];
      final color = _kPalette[i % _kPalette.length];
      final value = entry.value;
      final pct = total > 0 ? (value / total * 100) : 0.0;

      return PieChartSectionData(
        color: color,
        value: value,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      );
    });

    return _BaseCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s8,
      ),
      child: Column(
        children: [
          Semantics(
            label: top.isEmpty
                ? 'Category breakdown chart'
                : 'Category breakdown chart. Top category: ${catById[top.first.key] ?? top.first.key}, ${(total > 0 ? top.first.value / total * 100 : 0).toStringAsFixed(0)}%',
            child: SizedBox(
              height: 200,
              child: ExcludeSemantics(
                child: PieChart(PieChartData(sections: sections)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            children: top.asMap().entries.map((final e) {
              final idx = e.key;
              final entry = e.value;
              final color = _kPalette[idx % _kPalette.length];
              final catName = catById[entry.key] ?? entry.key;
              final pct = total > 0 ? (entry.value / total * 100) : 0.0;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$catName ${pct.toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Top Spends with bar indicators
// ════════════════════════════════════════════════════════════════════════════

class _MerchantsCard extends StatelessWidget {
  const _MerchantsCard({required this.merchants, required this.currency});
  final List<TopMerchant> merchants;
  final String currency;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final maxAmt = merchants.isNotEmpty ? merchants.first.amount : 1.0;

    return _BaseCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        children: List.generate(merchants.length, (final i) {
          final m = merchants[i];
          final fill = maxAmt > 0 ? (m.amount / maxAmt) : 0.0;
          final color = _kPalette[i % _kPalette.length];

          return Padding(
            padding: EdgeInsets.only(
              bottom: i < merchants.length - 1 ? AppSpacing.s16 : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        m.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatAmount(m.amount, currency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                ClipRRect(
                  borderRadius: AppRadius.fullAll,
                  child: AnimatedProgressIndicator(
                    progress: fill,
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.10),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Budgets bar list — shows spending per budget with matching legend and color
// ════════════════════════════════════════════════════════════════════════════

// Budgets card removed — budgets are shown on the Budgets screen.

// ════════════════════════════════════════════════════════════════════════════
// Recurring payments
// ════════════════════════════════════════════════════════════════════════════

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.recurring, required this.currency});
  final List<RecurringPayment> recurring;
  final String currency;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return _BaseCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Column(
        children: recurring.map((final r) {
          final days = r.avgInterval.inDays;
          final label = days <= 10
              ? 'Weekly'
              : days <= 18
              ? 'Bi-weekly'
              : days <= 35
              ? 'Monthly'
              : '${days}d cycle';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.10),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(
                    Icons.repeat_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.10),
                              borderRadius: AppRadius.fullAll,
                            ),
                            child: Text(
                              label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            '${r.occurrences}x detected',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAmount(r.avgAmount, currency),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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

// ════════════════════════════════════════════════════════════════════════════
// Unusual activity
// ════════════════════════════════════════════════════════════════════════════

class _AnomalyCard extends ConsumerWidget {
  const _AnomalyCard({required this.anomalies, required this.currency});
  final List<TransactionModel> anomalies;
  final String currency;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final datePattern = ref.watch(sharedPrefsServiceProvider).dateFormat;
    final show = anomalies.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.05),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 17,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'These transactions are unusually high for their category.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...show.map(
            (final t) => ListTile(
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 15,
                  color: AppColors.warning,
                ),
              ),
              title: Text(
                t.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                formatDate(t.date, datePattern),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              trailing: Text(
                formatAmount(t.amount.abs(), currency),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
