import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/illustrations/app_illustration.dart';
import '../../core/models/account.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/account_repository.dart';
import '../../core/ui/constants.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/format.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import 'account_form_sheet.dart';

/// Cards, UPI, cash and bank accounts the user can tag transactions with, each
/// with this month's spend.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _delete(final BuildContext context, final WidgetRef ref, final AccountModel a) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showConfirmDialog(
      context,
      title: 'Delete account',
      content: 'Delete "${a.name}"? This only works if no transactions use it.',
      confirmLabel: 'Delete',
    );
    if (confirm != true) return;
    try {
      await ref.read(userAccountsProvider.notifier).remove(a.id);
      ref.invalidate(accountMonthSpendProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } catch (e) {
      // e.g. "Cannot delete account with 12 transaction(s)"
      messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
    }
  }

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final accountsAsync = ref.watch(userAccountsProvider);
    final spend = ref.watch(accountMonthSpendProvider).value ?? const <String, AccountSpend>{};
    final currency = ref.watch(sharedPrefsServiceProvider).currency;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Cards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAccountFormSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: accountsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (final context, final i) => const SkeletonListTile(),
          separatorBuilder: (final context, final i) => const SizedBox(height: 8),
          itemCount: 5,
        ),
        error: (final e, _) => Center(
          child: AppEmptyState(
            title: 'Failed to load accounts',
            subtitle: repoErrorMessage(e),
            icon: Icons.error_outline_rounded,
            illustration: illustrationForError(e),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(userAccountsProvider),
          ),
        ),
        data: (final list) {
          if (list.isEmpty) {
            return Center(
              child: AppEmptyState(
                title: 'No cards or accounts yet',
                subtitle: 'Add a credit card, debit card, UPI app or cash so every transaction shows how it was paid.',
                icon: Icons.credit_card_outlined,
                illustration: AppIllustrationKind.tags,
                actionLabel: 'Add account',
                onAction: () => showAccountFormSheet(context),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userAccountsProvider);
              ref.invalidate(accountMonthSpendProvider);
              await ref.read(userAccountsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (final _, final i) => const SizedBox(height: 8),
              itemBuilder: (final ctx, final i) {
                final a = list[i];
                final month = spend[a.id];
                return MotionFadeIn(
                  delay: MotionStagger.delayFor(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.lgAll,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(a.kind.icon, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              Text(
                                [a.typeName, if (a.subtitle != null) a.subtitle!].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatAmount(month?.spend ?? 0, currency),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'spent this month',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                              ),
                            ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (final v) {
                            if (v == 'edit') showAccountFormSheet(context, existing: a);
                            if (v == 'delete') _delete(context, ref, a);
                          },
                          itemBuilder: (final _) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
