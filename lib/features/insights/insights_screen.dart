import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../core/illustrations/app_illustration.dart';
import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/budget_analytics_providers.dart';
import '../../core/providers/export_service_provider.dart';
import '../../core/providers/insights_account_providers.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/finance_style.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';

const List<Color> _kPalette = [
  AppColors.ocean700,
  AppColors.brandTeal,
  Color(0xFF7CC7CF),
  Color(0xFF5B6B79),
  Color(0xFF9AA8B4),
  Color(0xFFC9A66B),
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
    final scope = ref.watch(effectiveInsightsAccountProvider);
    final accounts = ref.watch(userAccountsProvider).value ?? const <AccountModel>[];
    // The server's breakdown covers every account, so it only answers "All
    // accounts"; a narrower scope is computed from that scope's transactions.
    final AsyncValue<Map<String, double>> categoryBreakdownAsync = scope == kInsightsAccountAll
        ? ref.watch(serverCategoryBreakdownProvider)
        : AsyncData(ref.watch(categoryBreakdownProvider));

    final topMerchants = ref.watch(topMerchantsProvider);
    final recurring = ref.watch(recurringPaymentsProvider);
    final anomalies = ref.watch(anomaliesProvider);
    final forecast = ref.watch(forecastExpenseNextMonthProvider);
    final accountRows = ref.watch(accountSpendRowsProvider);
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final currency = ref.watch(currencyProvider);
    final isLoading = txsAsync.isLoading;
    final scopeLabel = insightsScopeLabel(scope, accounts);

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
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportInsights(context, ref, categoryBreakdownAsync, kpis),
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(userAccountsProvider);
          await ref.read(recentTransactionsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.s4,
            AppSpacing.pagePadding,
            AppSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (txsAsync.hasError) ...[
                AppEmptyState(
                  title: 'Failed to load your latest transactions',
                  subtitle: repoErrorMessage(txsAsync.error ?? 'Unknown error'),
                  icon: Icons.error_outline_rounded,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(recentTransactionsProvider),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
              ],

              // ── What am I looking at? period + account ─────────────────────
              _RangeSegmented(
                selected: selectedRange,
                onChanged: (final r) => ref.read(selectedTimeRangeProvider.notifier).setRange(r),
              ),
              const SizedBox(height: AppSpacing.s12),
              _AccountScopeBar(
                scope: scope,
                accounts: accounts,
                onSelected: (final s) => ref.read(insightsAccountProvider.notifier).select(s),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── Net balance hero ───────────────────────────────────────────
              _NetHeroCard(
                kpis: kpis,
                currency: currency,
                isLoading: isLoading,
                scopeLabel: scopeLabel,
                rangeLabel: _rangeLongLabel(selectedRange),
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── Key figures ────────────────────────────────────────────────
              _StatGrid(kpis: kpis, currency: currency, isLoading: isLoading),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Forecast card ──────────────────────────────────────────────
              if (!isLoading && forecast != null) ...[
                _ForecastCard(forecast: forecast, monthly: monthly, currency: currency),
                const SizedBox(height: AppSpacing.sectionGap),
              ],

              // ── Spend by account ───────────────────────────────────────────
              const _SectionHeader(title: 'Spend by Account', icon: Icons.credit_card_rounded),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 160)
              else if (accountRows.isEmpty)
                const AppEmptyState(
                  title: 'No spending yet',
                  subtitle: 'Spending by card, UPI and cash shows up here',
                  icon: Icons.credit_card_outlined,
                  compact: true,
                )
              else
                _AccountSpendCard(
                  rows: accountRows,
                  currency: currency,
                  selectedScope: scope,
                  onSelected: (final s) => ref.read(insightsAccountProvider.notifier).select(s),
                ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Monthly trend ──────────────────────────────────────────────
              const _SectionHeader(title: 'Monthly Trend', icon: Icons.show_chart_rounded),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 200)
              else if (monthly.every((final v) => v == 0))
                const AppEmptyState(
                  title: 'No trend data',
                  subtitle: 'Add transactions to see your monthly trend',
                  icon: Icons.show_chart_rounded,
                  illustration: AppIllustrationKind.chart,
                )
              else
                _MonthlyTrendCard(monthly: monthly),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Category Breakdown ──────────────────────────────────────
              const _SectionHeader(title: 'Category Breakdown', icon: Icons.pie_chart_rounded),
              const SizedBox(height: AppSpacing.s12),
              categoryBreakdownAsync.when(
                loading: () => const SkeletonChartBox(height: 240),
                error: (final err, final stack) => const AppEmptyState(
                  title: 'Failed to load category data',
                  subtitle: 'Unable to fetch category breakdown from server',
                  compact: true,
                ),
                data: (final breakdown) {
                  if (breakdown.isEmpty) {
                    return const AppEmptyState(
                      title: 'No category data',
                      subtitle: 'Add transactions to see category breakdown',
                      compact: true,
                    );
                  }
                  return _CategoryBreakdownCard(breakdown: breakdown, currency: currency);
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Top Spends ──────────────────────────────────────────────
              const _SectionHeader(title: 'Top Spends', icon: Icons.storefront_rounded),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 180)
              else if (topMerchants.isEmpty)
                const AppEmptyState(
                  title: 'No merchant data',
                  subtitle: 'No merchant data for this period',
                  compact: true,
                )
              else
                _MerchantsCard(merchants: topMerchants, currency: currency),
              const SizedBox(height: AppSpacing.sectionGap),

              // ── Recurring payments ─────────────────────────────────────────
              const _SectionHeader(title: 'Recurring Payments', icon: Icons.repeat_rounded),
              const SizedBox(height: AppSpacing.s12),
              if (isLoading)
                const SkeletonChartBox(height: 140)
              else if (recurring.isEmpty)
                const AppEmptyState(
                  title: 'No recurring payments',
                  subtitle: 'No recurring payments detected yet',
                  compact: true,
                )
              else
                _RecurringCard(recurring: recurring, currency: currency),

              // ── Unusual activity ───────────────────────────────────────────
              if (!isLoading && anomalies.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sectionGap),
                const _SectionHeader(title: 'Unusual Activity', icon: Icons.warning_amber_rounded),
                const SizedBox(height: AppSpacing.s12),
                _AnomalyCard(anomalies: anomalies, currency: currency),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _rangeLongLabel(final TimeRange r) => switch (r) {
      TimeRange.last7d => 'Last 7 days',
      TimeRange.last30d => 'Last 30 days',
      TimeRange.last90d => 'Last 90 days',
    };

// ════════════════════════════════════════════════════════════════════════════
// Shared primitives
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  // Kept for call-site compatibility; the serious layout uses text-only labels.
  final IconData icon;

  @override
  Widget build(final BuildContext context) => SectionLabel(title);
}

/// Flat, hairline-bordered surface shared by every insight card.
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
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: theme.brightness == Brightness.light ? AppShadow.soft : null,
      ),
      child: child,
    );
  }
}

/// A neutral "share of the total" bar.
///
/// Not [AnimatedProgressIndicator]: that one is a *budget* meter (orange past
/// 90%, red at 100%), which would flag the biggest merchant or account as
/// "overspent" just for being the largest slice.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(final BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        builder: (final context, final value, final _) => LinearProgressIndicator(
          value: value,
          minHeight: 4,
          color: color,
          backgroundColor: color.withValues(alpha: 0.10),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Period + account controls
// ════════════════════════════════════════════════════════════════════════════

/// Full-width 7 / 30 / 90 day control. Three equal segments, so it lines up
/// with the cards below instead of floating in the app bar.
class _RangeSegmented extends StatelessWidget {
  const _RangeSegmented({required this.selected, required this.onChanged});
  final TimeRange selected;
  final ValueChanged<TimeRange> onChanged;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        children: [
          for (final r in TimeRange.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: r == selected,
                label: _rangeLongLabel(r),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: r == selected ? theme.colorScheme.primary : Colors.transparent,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      switch (r) {
                        TimeRange.last7d => '7 days',
                        TimeRange.last30d => '30 days',
                        TimeRange.last90d => '90 days',
                      },
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: r == selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.66),
                        fontWeight: r == selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Default account" (nothing chosen), "All accounts", then each card / UPI /
/// cash. Scrolls sideways, so any number of accounts fits on one line.
class _AccountScopeBar extends StatelessWidget {
  const _AccountScopeBar({required this.scope, required this.accounts, required this.onSelected});
  final String scope;
  final List<AccountModel> accounts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    // The server-made "Default Account" is what the first chip already means.
    final others = accounts.where((final a) => a.name.trim().toLowerCase() != 'default account').toList();

    Widget chip({
      required final String value,
      required final String label,
      required final IconData icon,
    }) {
      final selected = scope == value;
      return ChoiceChip(
        avatar: Icon(icon, size: 16, color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(value),
      );
    }

    // A handful of chips in a sideways-scrolling row (all built up front, so
    // each one can be reached and focused, unlike a lazily built list).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(value: kInsightsAccountDefault, label: 'Default account', icon: Icons.account_balance_wallet_outlined),
          const SizedBox(width: AppSpacing.s8),
          chip(value: kInsightsAccountAll, label: 'All accounts', icon: Icons.layers_outlined),
          for (final a in others) ...[
            const SizedBox(width: AppSpacing.s8),
            chip(value: a.id, label: a.shortLabel, icon: a.kind.icon),
          ],
        ],
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
    required this.scopeLabel,
    required this.rangeLabel,
  });
  final Kpis kpis;
  final String currency;
  final bool isLoading;
  final String scopeLabel;
  final String rangeLabel;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = kpis.net >= 0;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);
    final tone = isPositive ? AppColors.success : AppColors.error;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Net balance', style: theme.textTheme.labelLarge?.copyWith(color: muted)),
              ),
              // Direction is stated in words and an icon, not colour alone.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.10),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: tone),
                    const SizedBox(width: 4),
                    Text(
                      isPositive ? 'Surplus' : 'Deficit',
                      style: theme.textTheme.labelMedium?.copyWith(color: tone, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          if (isLoading)
            const SkeletonLine(height: 32, width: 160)
          else
            SizedBox(
              width: double.infinity,
              child: AmountText(
                amount: kpis.net,
                currency: currency,
                alignment: Alignment.centerLeft,
                style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
              ),
            ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '$scopeLabel · $rangeLabel · ${kpis.txCount} ${kpis.txCount == 1 ? 'transaction' : 'transactions'}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Key figures: Income | Expenses / Savings rate | Daily average
// ════════════════════════════════════════════════════════════════════════════

/// Four equal tiles in a 2x2 grid. Label on top, value below, everything
/// left-aligned to the same edge, so figures read down and across cleanly.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.kpis, required this.currency, required this.isLoading});
  final Kpis kpis;
  final String currency;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final savingsPct = (kpis.savingsRate * 100).clamp(0, 100);

    Widget plain(final String text) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: tabular(theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
        );

    Widget money(final num amount, {final bool signed = true}) => SizedBox(
          width: double.infinity,
          child: AmountText(
            amount: amount,
            currency: currency,
            showSign: signed,
            alignment: Alignment.centerLeft,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        );

    final tiles = [
      _StatTile(key: const ValueKey('stat-income'), icon: Icons.south_west_rounded, label: 'Income', isLoading: isLoading, value: money(kpis.income)),
      _StatTile(key: const ValueKey('stat-expenses'), icon: Icons.north_east_rounded, label: 'Expenses', isLoading: isLoading, value: money(-kpis.expense.abs())),
      _StatTile(key: const ValueKey('stat-savings'), icon: Icons.savings_outlined, label: 'Savings rate', isLoading: isLoading, value: plain('${savingsPct.toStringAsFixed(1)}%')),
      _StatTile(key: const ValueKey('stat-daily'), icon: Icons.calendar_today_outlined, label: 'Daily average', isLoading: isLoading, value: money(kpis.avgDailySpend, signed: false)),
    ];

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: tiles[1]),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: tiles[3]),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.icon, required this.label, required this.value, required this.isLoading});
  final IconData icon;
  final String label;
  final Widget value;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);
    return _BaseCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: muted),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (isLoading) const SkeletonLine(height: 18, width: 84) else value,
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
              color: theme.brightness == Brightness.dark ? AppColors.darkSurfaceHigh : AppColors.tint050,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              color: theme.brightness == Brightness.dark ? AppColors.ocean400 : AppColors.ocean700,
              size: 24,
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                SizedBox(
                  width: double.infinity,
                  child: AmountText(
                    amount: forecast,
                    currency: currency,
                    showSign: false,
                    alignment: Alignment.centerLeft,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (lastMonth != 0) ...[
            const SizedBox(width: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
              decoration: BoxDecoration(
                borderRadius: AppRadius.smAll,
                border: Border.all(color: changeColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: changeColor),
                  const SizedBox(width: 3),
                  Text(
                    '${pct.abs().toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall?.copyWith(color: changeColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Spend by account
// ════════════════════════════════════════════════════════════════════════════

/// Every account's spend for the period, largest first, with a share bar.
/// Tapping a row drills the whole page into that account.
class _AccountSpendCard extends StatelessWidget {
  const _AccountSpendCard({
    required this.rows,
    required this.currency,
    required this.selectedScope,
    required this.onSelected,
  });
  final List<AccountSpendRow> rows;
  final String currency;
  final String selectedScope;
  final ValueChanged<String> onSelected;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.66);
    final total = rows.fold<double>(0, (final s, final r) => s + r.spend);

    return _BaseCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.6)),
            Builder(builder: (final context) {
              final r = rows[i];
              final color = _kPalette[i % _kPalette.length];
              final share = total > 0 ? r.spend / total : 0.0;
              final isSelected = r.scope == selectedScope;
              return InkWell(
                onTap: () => onSelected(r.scope),
                borderRadius: AppRadius.mdAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: AppRadius.smAll),
                            child: Icon(r.kind.icon, size: 18, color: color),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600),
                                ),
                                Text(
                                  [if (r.subtitle != null) r.subtitle!, '${r.count} ${r.count == 1 ? 'transaction' : 'transactions'}'].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatAmount(r.spend, currency),
                                style: tabular(theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              Text(
                                '${(share * 100).toStringAsFixed(0)}%',
                                style: tabular(theme.textTheme.bodySmall?.copyWith(color: muted)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _ShareBar(fraction: share, color: color),
                    ],
                  ),
                ),
              );
            }),
          ],
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
      // No in-slice labels: percentages live in the legend list below, where
      // they can't collide on small slices or fail contrast on light slices.
      return PieChartSectionData(
        color: color,
        value: value,
        radius: 26,
        showTitle: false,
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
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 58,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          // Legend as a list: colour dot + name on the left, share and amount
          // on the right, so identity never depends on the colour ramp alone.
          for (var idx = 0; idx < top.length; idx++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _kPalette[idx % _kPalette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      catById[top[idx].key] ?? top[idx].key,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    '${(total > 0 ? top[idx].value / total * 100 : 0).toStringAsFixed(0)}%',
                    style: tabular(theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                    )),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Flexible(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AmountText(
                        amount: -top[idx].value.abs(),
                        currency: currency,
                        showSign: false,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
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
                _ShareBar(fraction: fill, color: color),
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
