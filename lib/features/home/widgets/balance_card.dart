import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/insights_providers.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../../../core/ui/constants.dart';
import '../../../core/ui/finance_style.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';

/// The month's net position: one flat, solid surface with a single large
/// figure and a hairline-separated Income | Expense pair. No gradients, arcs
/// or glow — the number is the design.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final currency = ref.watch(sharedPrefsServiceProvider.select((final s) => s.currency));
    final kpis = ref.watch(currentMonthKpisProvider);
    final status = getBalanceStatus(kpis.net, currency);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    const onHero = Colors.white;
    final muted = onHero.withValues(alpha: 0.72);
    final label = theme.textTheme.labelMedium?.copyWith(color: muted, fontWeight: FontWeight.w600);

    return Semantics(
      container: true,
      label: '${l10n?.homeNetBalance ?? 'Net balance'}, ${status.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(
          color: AppColors.ocean800,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: onHero.withValues(alpha: 0.08)),
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n?.homeNetBalance ?? 'Net balance', style: label)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: onHero.withValues(alpha: 0.24)),
                    ),
                    child: Text(l10n?.homeThisMonth ?? 'This month', style: label),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: AmountText(
                  key: ValueKey(kpis.net),
                  amount: kpis.net,
                  currency: currency,
                  showSign: kpis.net < 0,
                  alignment: Alignment.centerLeft,
                  color: onHero,
                  incomeColor: onHero,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: onHero,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Icon(
                    status.isPositive ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    size: 16,
                    color: status.isPositive ? kIncomeOnHero : const Color(0xFFFFB4B4),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      status.message,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Container(height: 1, color: onHero.withValues(alpha: 0.16)),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      icon: Icons.south_west_rounded,
                      label: l10n?.income ?? 'Income',
                      amount: kpis.income,
                      currency: currency,
                      labelStyle: label,
                    ),
                  ),
                  Container(width: 1, height: 36, color: onHero.withValues(alpha: 0.16)),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _Figure(
                      icon: Icons.north_east_rounded,
                      label: l10n?.expense ?? 'Expense',
                      amount: -kpis.expense.abs(),
                      currency: currency,
                      labelStyle: label,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.icon,
    required this.label,
    required this.amount,
    required this.currency,
    required this.labelStyle,
  });

  final IconData icon;
  final String label;
  final num amount;
  final String currency;
  final TextStyle? labelStyle;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: labelStyle?.color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: labelStyle, overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 4),
        AmountText(
          amount: amount,
          currency: currency,
          alignment: Alignment.centerLeft,
          color: Colors.white,
          incomeColor: kIncomeOnHero,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}
