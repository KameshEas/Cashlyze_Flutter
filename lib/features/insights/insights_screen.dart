import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/ui/constants.dart';
import '../../core/widgets/animated_progress_indicator.dart';

const List<Color> _kPalette = [
  AppColors.emerald600,
  AppColors.teal500,
  AppColors.info,
  AppColors.warning,
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
];

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(recentTransactionsProvider);
    final kpis = ref.watch(kpisProvider);
    final monthly = ref.watch(monthlyTrendProvider);
    
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
          _TimeRangePicker(
            selected: selectedRange,
            onChanged: (r) =>
                ref.read(selectedTimeRangeProvider.notifier).setRange(r),
          ),
          const SizedBox(width: AppSpacing.s16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          0,
          AppSpacing.pagePadding,
          AppSpacing.pagePadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Net balance hero ───────────────────────────────────────────
            _NetHeroCard(kpis: kpis, currency: currency, isLoading: isLoading),
            const SizedBox(height: AppSpacing.s12),

            // ── 4-metric strip ─────────────────────────────────────────────
            _MetricStrip(kpis: kpis, currency: currency, isLoading: isLoading),
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

            // Category breakdown removed per request.

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
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared primitives
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
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
  final Widget child;
  final EdgeInsets? padding;
  const _BaseCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
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
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;
  const _TimeRangePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeRange.values.map((r) {
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
                color:
                    isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: AppRadius.fullAll,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? Colors.white
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
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
  final Kpis kpis;
  final String currency;
  final bool isLoading;
  const _NetHeroCard({
    required this.kpis,
    required this.currency,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
  final Kpis kpis;
  final String currency;
  final bool isLoading;
  const _MetricStrip({
    required this.kpis,
    required this.currency,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
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
            value: isLoading
                ? null
                : '${savingsPct.toStringAsFixed(1)}%',
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
  final IconData icon;
  final Color color;
  final String label;
  final String? value; // null = loading
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
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
  final double forecast;
  final List<double> monthly;
  final String currency;
  const _ForecastCard({
    required this.forecast,
    required this.monthly,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
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
  final List<double> monthly;
  const _MonthlyTrendCard({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return _BaseCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s12,
        AppSpacing.s8,
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
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
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= monthly.length) {
                      return const SizedBox.shrink();
                    }
                    final now = DateTime.now();
                    final offset = monthly.length - 1 - idx;
                    final m = DateTime(now.year, now.month - offset, 1);
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
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
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
                  (i) => FlSpot(i.toDouble(), monthly[i]),
                ),
                isCurved: true,
                curveSmoothness: 0.35,
                barWidth: 2.5,
                color: color,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, bar, i) => FlDotCirclePainter(
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
    );
  }
}

// Category breakdown removed from Insights.

// ════════════════════════════════════════════════════════════════════════════
// Top Spends with bar indicators
// ════════════════════════════════════════════════════════════════════════════

class _MerchantsCard extends StatelessWidget {
  final List<TopMerchant> merchants;
  final String currency;
  const _MerchantsCard({required this.merchants, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAmt = merchants.isNotEmpty ? merchants.first.amount : 1.0;

    return _BaseCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        children: List.generate(merchants.length, (i) {
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
                        m.name.isNotEmpty
                            ? m.name[0].toUpperCase()
                            : '?',
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
  final List<RecurringPayment> recurring;
  final String currency;
  const _RecurringCard({required this.recurring, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _BaseCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Column(
        children: recurring.map((r) {
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

class _AnomalyCard extends StatelessWidget {
  final List<TransactionModel> anomalies;
  final String currency;
  const _AnomalyCard({required this.anomalies, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final show = anomalies.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.05),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
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
            (t) => ListTile(
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
                DateFormat('dd MMM yyyy').format(t.date),
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

