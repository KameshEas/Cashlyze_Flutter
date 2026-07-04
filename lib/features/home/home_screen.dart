import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/recurring_providers.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/balance_card.dart';
import 'widgets/quick_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recurringProcessorProvider);
    final currency = ref.watch(
      sharedPrefsServiceProvider.select((s) => s.currency),
    );
    final txsAsync = ref.watch(recentTransactionsProvider);
    final plansAsync = ref.watch(userEMIPlansProvider);
    final hasEmis = plansAsync.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.dashboard ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications coming soon'),
                duration: Duration(seconds: 2),
              ),
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              try {
                ref.invalidate(userEMIPlansProvider);
                ref.invalidate(emiUpcomingProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing EMI data')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Refresh failed: $e')),
                );
              }
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _performRefresh(context, ref),
        displacement: 40.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: MotionStagger(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BalanceCard(),
              const SizedBox(height: 40),
              Text(
                t?.quickActions ?? 'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const QuickActions(),
              if (hasEmis) ...[
                const SizedBox(height: 24),
                Text(
                  t?.emiTracker ?? 'EMI Tracker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildUpcomingEmi(context, ref, currency),
              ],
              const SizedBox(height: 24),
              Text(
                t?.recentTransactions ?? 'Recent Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRecentTransactions(context, ref, currency, txsAsync),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEmi(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) {
    final upcomingAsync = ref.watch(emiUpcomingProvider);
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return MotionSwitcher(
      child: upcomingAsync.when(
      loading: () => const SizedBox(
        key: ValueKey('emi-loading'),
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        key: const ValueKey('emi-error'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Text('EMI load error: $e'),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink(key: ValueKey('emi-empty'));
        return Column(
          key: const ValueKey('emi-data'),
          children: items.take(3).map((e) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final dueDays = e.dueDate.difference(today).inDays;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, size: 18),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAmount(e.installment, currency),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dueDays < 0
                            ? 'Overdue'
                            : dueDays == 0
                                ? 'Due Today'
                                : 'Due in $dueDays days',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dueDays < 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    String currency,
    AsyncValue<List<TransactionModel>> txsAsync,
  ) {
    return MotionSwitcher(
      child: txsAsync.when(
      loading: () => Column(
        key: const ValueKey('rt-loading'),
        children: const [
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
        ],
      ),
      error: (e, _) => Container(
        key: const ValueKey('rt-error'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('Failed to load: $e')),
          ],
        ),
      ),
      data: (items) {
        final now = DateTime.now();
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonthStart = DateTime(now.year, now.month + 1, 1);
        final monthItems = items
            .where(
              (t) =>
                  t.date.isAfter(
                    monthStart.subtract(const Duration(seconds: 1)),
                  ) &&
                  t.date.isBefore(nextMonthStart),
            )
            .toList();

        if (monthItems.isEmpty) {
          return Center(
            key: const ValueKey('rt-empty'),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'No recent transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }
        return Column(
          key: const ValueKey('rt-data'),
          children: monthItems.take(2).map((tx) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RecentTransactionItem(
                tx: tx,
                currency: currency,
              ),
            );
          }).toList(),
        );
      },
    ),
    );
  }

  Future<void> _performRefresh(final BuildContext context, final WidgetRef ref) async {
    try {
      ref.invalidate(currentMonthKpisProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(userEMIPlansProvider);
      ref.invalidate(emiUpcomingProvider);
      ref.invalidate(recurringProcessorProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// A single recent transaction item displayed on the home screen.
class RecentTransactionItem extends StatelessWidget {
  final TransactionModel tx;
  final String currency;

  const RecentTransactionItem({
    super.key,
    required this.tx,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayCategory = tx.categoryName ?? tx.categoryId ?? 'General';
    final isIncome = tx.amount >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayCategory,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatAmount(tx.amount, currency),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isIncome
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}