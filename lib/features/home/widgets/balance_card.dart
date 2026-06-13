import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/insights_providers.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';

/// Displays the user's current month balance with income/expense breakdown.
/// Features enhanced animations and modern UI styling.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final currency =
        ref.watch(sharedPrefsServiceProvider.select((final s) => s.currency));
    final kpis = ref.watch(currentMonthKpisProvider);
    final balanceStatus = getBalanceStatus(kpis.net, currency);
    final isPositive = balanceStatus.isPositive;
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (final context, final scale, final child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title + Period
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Balance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'This Month',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Primary Status Message with Animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (final child, final animation) =>
                  ScaleTransition(
                scale: animation,
                child: child,
              ),
              child: Column(
                key: ValueKey(kpis.net),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          balanceStatus.message,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusIndicator(isPositive),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Net: ${formatAmount(kpis.net, currency)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Income & Expense Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: _buildDetail(
                    context,
                    AppLocalizations.of(context)?.income ?? 'Income',
                    formatAmount(kpis.income, currency),
                    Icons.arrow_downward,
                    theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: _buildDetail(
                    context,
                    AppLocalizations.of(context)?.expense ?? 'Expense',
                    formatAmount(kpis.expense, currency),
                    Icons.trending_up,
                    theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStatusIndicator(final bool isPositive) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPositive ? Colors.greenAccent : Colors.redAccent,
        boxShadow: [
          BoxShadow(
            color: (isPositive ? Colors.greenAccent : Colors.redAccent)
                .withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          isPositive ? Icons.check : Icons.close,
          color: Colors.black87,
          size: 12,
          weight: 700,
        ),
      ),
    );
  }

  static Widget _buildDetail(
    final BuildContext context,
    final String label,
    final String amount,
    final IconData icon,
    final Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isExpense = label.toLowerCase().contains('expense');
    final bgColor = isExpense
        ? scheme.error.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}