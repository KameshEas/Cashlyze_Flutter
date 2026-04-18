import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../core/providers/insights_providers.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/services/transaction_ingest_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/category_picker_field.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/emi_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/realtime_db_service.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/providers/recurring_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recurringProcessorProvider);
    final currency = ref.watch(currencyProvider);
    // Use current-month KPIs so the home "This Month" card matches
    // the data and aligns with the Transactions default view.
    final kpis = ref.watch(currentMonthKpisProvider);
    final txsAsync = ref.watch(recentTransactionsProvider);
    final mismatch = ref.watch(databaseUrlMismatchProvider);
    final dbUrl = ref.watch(databaseUrlProvider);
    // Watch EMI list here so we can conditionally render the section.
    final emiAsync = ref.watch(emiUpcomingProvider);
    final plansAsync = ref.watch(userEMIPlansProvider);
    // Show the EMI section while either the plans or upcoming streams are
    // loading or when either has data. This reduces flicker when streams
    // reconnect or are briefly delayed.
    final hasEmis = (
      plansAsync.maybeWhen(data: (list) => list.isNotEmpty, loading: () => true, orElse: () => false)
    ) || (
      emiAsync.maybeWhen(data: (list) => list.isNotEmpty, loading: () => true, orElse: () => false)
    );
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t?.dashboard ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            // Notifications coming in a future release.
            // Showing an empty handler breaks trust — use SnackBar as placeholder.
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications coming soon'),
                duration: Duration(seconds: 2),
              ),
            ),
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mismatch)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Connected to $dbUrl. Expected asia-southeast1 instance.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            _buildBalanceCard(context, currency, kpis),
            const SizedBox(height: 24),
            Text(
              t?.quickActions ?? 'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(context, ref),
            // ── EMI section: only shown when the user has EMI plans ───────────
            // Progressive disclosure: empty section adds noise for non-EMI users.
            if (hasEmis) ...
              [
                const SizedBox(height: 24),
                Text(
                  t?.emiTracker ?? 'EMI Tracker',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildUpcomingEmi(context, ref, currency),
              ],
            const SizedBox(height: 24),
                Text(
                  t?.recentTransactions ?? 'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
            const SizedBox(height: 16),
            _buildRecentTransactions(context, ref, currency, txsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, String currency, Kpis kpis) {
    final balanceStatus = getBalanceStatus(kpis.net, currency);
    final isPositive = balanceStatus.isPositive;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'This Month',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Primary Status Message (Animated)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Column(
              key: ValueKey(kpis.net),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status message row with indicator
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        balanceStatus.message,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // Status indicator circle (green/red)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPositive ? Colors.greenAccent : Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: isPositive 
                                ? Colors.greenAccent.withValues(alpha: 0.5)
                                : Colors.redAccent.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Secondary: Net balance (small text)
                Text(
                  'Net: ${formatAmount(kpis.net, currency)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Income & Expense Breakdown (existing, unchanged)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceDetail(
                context,
                AppLocalizations.of(context)?.income ?? 'Income',
                formatAmount(kpis.income, currency),
                Icons.arrow_downward,
                Theme.of(context).colorScheme.secondary,
              ),
              _buildBalanceDetail(
                context,
                AppLocalizations.of(context)?.expense ?? 'Expense',
                formatAmount(kpis.expense, currency),
                Icons.arrow_upward,
                Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDetail(
    BuildContext context,
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isExpense = label.toLowerCase().contains('expense');
    final bg = isExpense
        ? scheme.error.withValues(alpha: 0.2)
        : color.withValues(alpha: 0.15);
    final border = isExpense
        ? Border.all(color: scheme.error.withValues(alpha: 0.35))
        : null;
    final ic = isExpense ? Icons.trending_up : icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                amount,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final actions = [
      {
        'icon': Icons.remove,
        'label': 'Expense',
        'type': 'Expense',
        'category': 'General',
      },
      {
        'icon': Icons.add_card,
        'label': t?.quickTopUp ?? 'Top-up',
        'type': 'Income',
        'category': 'Income',
      },
      // Bottom-sheet items brought into the quick actions row
      {
        'icon': Icons.payments,
        'label': 'Add EMI',
        'route': '/emi/new',
      },
      {
        'icon': Icons.savings,
        'label': 'Add Budget',
        'route': '/budgets',
      },
      {
        'icon': Icons.camera_alt,
        'label': 'Scan',
        'action': 'scan',
      },
    ];

    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: actions.map((action) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Semantics(
              label: '${action['label']} action',
              button: true,
              child: InkWell(
                onTap: () {
                  if (action.containsKey('route')) {
                    GoRouter.of(context).go(action['route'] as String);
                  } else if (action.containsKey('type')) {
                    _openQuickAdd(
                      context,
                      ref,
                      type: action['type'] as String,
                      category: action['category'] as String,
                    );
                  } else if (action['action'] == 'scan') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scan receipt not implemented')),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                focusColor: scheme.primary.withValues(alpha: 0.1),
                hoverColor: scheme.secondary.withValues(alpha: 0.08),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: scheme.secondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentTransactions(
    BuildContext context,
    WidgetRef ref,
    String currency,
    AsyncValue<List<TransactionModel>> txsAsync,
  ) {
    return txsAsync.when(
      loading: () => Column(
        children: const [
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
          SizedBox(height: 12),
          SkeletonListTile(),
        ],
      ),
      error: (e, _) => Container(
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
        // Show only transactions from the current calendar month so this
        // section matches the "This Month" summary above and the
        // Transactions screen default view.
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
        final list = monthItems.take(3).toList();
        return Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              _buildTransactionItem(
                context,
                list[i].title,
                list[i].categoryId ?? 'Uncategorized',
                formatAmount(list[i].amount, currency),
                list[i].amount >= 0,
              ),
              if (i < list.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    String title,
    String category,
    String amount,
    bool isIncome,
  ) {
    final theme = Theme.of(context);
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
                  title,
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
                  child: Text(category, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          Text(
            amount,
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

  Future<void> _openQuickAdd(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    required String category,
  }) async {
    final theme = Theme.of(context);
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String localType = type;
    String localCategory = category;
    DateTime date = DateTime.now();
    // Prefill from draft
    final prefs = ref.read(sharedPrefsServiceProvider);
    final draft = prefs.getDraft('home_quick_add');
    if (draft != null) {
      titleController.text = (draft['title'] as String?) ?? '';
      final amt = draft['amount'];
      if (amt != null) amountController.text = amt.toString();
      localType = (draft['type'] as String?) ?? localType;
      localCategory = (draft['category'] as String?) ?? localCategory;
      final ds = draft['date'] as String?;
      if (ds != null) {
        final parsed = DateTime.tryParse(ds);
        if (parsed != null) date = parsed;
      }
    }
    final result = await Future.microtask(() => showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        // Wrap the sheet in a StatefulBuilder so local sheet state (date,
        // selected type/category) can update the UI when mutated.
        return StatefulBuilder(builder: (sheetCtx2, setSheetState) {
          // Use a Consumer inside the StatefulBuilder so it rebuilds when
          // categories/budgets load while still allowing local state updates.
          return Consumer(builder: (sheetCtx, sheetRef, _) {
            final messenger = ScaffoldMessenger.of(sheetCtx);
            final nav = Navigator.of(sheetCtx);

          // Build category list from user categories + budgets so Quick Add
          // uses the same options as the full Transactions screen.
          final cats = sheetRef.watch(userCategoriesProvider).maybeWhen(data: (d) => d, orElse: () => const []);
          final categoryItems = <DropdownMenuItem<String>>[
            const DropdownMenuItem(value: 'General', child: Text('General')),
          ];
          final addedValues = <String>{'general'};
          for (final c in cats) {
            final name = (c.name ?? '').trim();
            if (name.isEmpty) continue;
            if (!addedValues.contains(name.toLowerCase())) {
              categoryItems.add(
                DropdownMenuItem(
                  value: name,
                  child: Row(children: [Expanded(child: Text(name, overflow: TextOverflow.ellipsis))]),
                ),
              );
              addedValues.add(name.toLowerCase());
            }
          }
          final catsList = cats;
          final idToNameHome = <String, String>{};
          final nameToIdHome = <String, String>{};
          for (final c in catsList) {
            final nm = (c.name ?? '').trim();
            if (nm.isEmpty) continue;
            idToNameHome[c.id] = nm;
            nameToIdHome[nm.toLowerCase()] = c.id;
          }

          final budgets = sheetRef.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);
          for (final b in budgets) {
            final catIds = b.categoryIds ?? <String>[];
            String key = '';
            if (catIds.isNotEmpty) {
              final raw = catIds.first.trim();
              if (raw.isEmpty) {
                key = (b.name ?? '').trim();
              } else if (idToNameHome.containsKey(raw)) {
                key = idToNameHome[raw]!.trim();
              } else {
                final mappedId = nameToIdHome[raw.toLowerCase()];
                if (mappedId != null) {
                  key = idToNameHome[mappedId] ?? raw;
                } else {
                  key = (b.name ?? raw).trim();
                }
              }
            } else {
              key = (b.name ?? '').trim();
            }
            if (key.isEmpty) continue;
            final keyLower = key.toLowerCase();
            if (!addedValues.contains(keyLower)) {
              categoryItems.add(
                DropdownMenuItem(
                  value: key,
                  child: Row(children: [Expanded(child: Text('${(b.name ?? key)} (Budget)', overflow: TextOverflow.ellipsis))]),
                ),
              );
              addedValues.add(keyLower);
            }
          }

          // Ensure the initially selected category matches exactly one
          // dropdown item. If it doesn't, fall back to the first item
          // to avoid Flutter's Dropdown assertion.
          // Map stored draft/local category id -> display name when possible
          String displayLocalCategory = (localCategory ?? '').trim();
          if (displayLocalCategory.isNotEmpty && idToNameHome.containsKey(displayLocalCategory)) {
            displayLocalCategory = idToNameHome[displayLocalCategory]!.trim();
          } else {
            final mappedId = nameToIdHome[displayLocalCategory.toLowerCase()];
            if (mappedId != null) displayLocalCategory = idToNameHome[mappedId] ?? displayLocalCategory;
          }
          final matchingCountHome = categoryItems.where((it) => it.value == displayLocalCategory).length;
          final effectiveInitialLocalCategory = matchingCountHome == 1
              ? displayLocalCategory
              : (categoryItems.isNotEmpty ? categoryItems.first.value : null);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: localType,
                          items: const [
                            DropdownMenuItem(
                              value: 'Expense',
                              child: Text('Expense'),
                            ),
                            DropdownMenuItem(
                              value: 'Income',
                              child: Text('Income'),
                            ),
                          ],
                          onChanged: (v) => setSheetState(() => localType = v ?? 'Expense'),
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CategoryPickerField(
                          value: effectiveInitialLocalCategory ?? (localCategory ?? 'General'),
                          onChanged: (v) => setSheetState(() => localCategory = v),
                          label: 'Category',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDate: date,
                            );
                            if (picked != null) setSheetState(() => date = picked);
                          },
                          child: Text(
                            '${AppLocalizations.of(ctx)?.dateLabel ?? 'Date:'} ${formatDate(date.toLocal(), prefs.dateFormat)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          final user = ref.read(currentUserProvider);
                          if (user == null) return;
                          final amount = double.tryParse(amountController.text) ?? 0;
                          final ingest = ref.read(
                            transactionIngestServiceProvider,
                          );
                          try {
                            await ingest.addManual(
                              userId: user.uid,
                              title: titleController.text,
                              amount: amount,
                              isIncome: localType == 'Income',
                              categoryId: localCategory == 'General' ? null : localCategory,
                              date: date,
                              notes: null,
                            );
                            // Pop the sheet and let the caller show the success snackbar
                            nav.pop(true);
                          } catch (e) {
                            // Show failures immediately
                            messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      });
      },
    ));
    final messenger = ScaffoldMessenger.of(context);
    if (result == true) {
      await prefs.clearDraft('home_quick_add');
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)?.transactionSaved ?? 'Transaction saved')));
    } else {
      final hasData =
          titleController.text.trim().isNotEmpty ||
          amountController.text.trim().isNotEmpty;
      if (hasData) {
        await prefs.saveDraft('home_quick_add', {
          'title': titleController.text.trim(),
          'amount': double.tryParse(amountController.text.trim()),
          'type': localType,
          'category': localCategory,
          'date': date.toIso8601String(),
        });
        messenger.showSnackBar(const SnackBar(content: Text('Draft saved')));
      }
    }
    // Do not dispose controllers here; they are tied to the bottom
    // sheet lifecycle and disposing them synchronously can race with
    // framework rebuilds and cause "used after dispose" assertions.
  }

  Future<void> _openQuickActionsMenu(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    await Future.microtask(() => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.32,
          minChildSize: 0.18,
          maxChildSize: 0.9,
          builder: (sheetCtx, controller) {
            return SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          // Add EMI (single)
                          InkWell(
                            onTap: () {
                              nav.pop();
                              Future.microtask(() => GoRouter.of(context).go('/emi/new'));
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 92,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.payments, size: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Add EMI', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                          // Add Budget
                          InkWell(
                            onTap: () {
                              nav.pop();
                              Future.microtask(() => GoRouter.of(context).go('/budgets'));
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 92,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.savings, size: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Add Budget', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                          // Scan Receipt (placeholder)
                          InkWell(
                            onTap: () {
                              nav.pop();
                              Future.microtask(() => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Scan receipt not implemented')),
                              ));
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 92,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 20),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Scan', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ));
  }

  Widget _buildUpcomingEmi(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) {
    final upcomingAsync = ref.watch(emiUpcomingProvider);
    final theme = Theme.of(context);
    return upcomingAsync.when(
      loading: () => const SkeletonListTile(),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
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
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_today, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)?.emiUpcoming ?? 'Upcoming EMI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.credit_card, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.noUpcomingEmi ??
                            'No upcoming EMI this month',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => GoRouter.of(context).go('/emi/new'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.setReminder ??
                            'Set Reminder',
                      ),
                    ),
                  ],
                )
              else ...[
                for (var i = 0; i < items.take(3).length; i++) ...[
                  Builder(builder: (ctx) {
                    final e = items[i];
                    final now = DateTime.now();
                    final dueDays = e.dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
                    Color pillColor;
                    String pillLabel;
                    if (dueDays < 0) {
                      pillColor = Colors.red;
                      pillLabel = 'Overdue';
                    } else if (dueDays == 0) {
                      pillColor = Colors.orange;
                      pillLabel = 'Due Today';
                    } else if (dueDays == 1) {
                      pillColor = Colors.orange;
                      pillLabel = 'Due Tomorrow';
                    } else {
                      pillColor = Colors.green;
                      pillLabel = 'Due in $dueDays days';
                    }
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.credit_card, size: 18),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formatAmount(e.installment, currency),
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: pillColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        pillLabel,
                                        style: theme.textTheme.bodySmall?.copyWith(color: pillColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final user = ref.read(currentUserProvider);
                              if (user == null) return;
                              HapticFeedback.lightImpact();
                              try {
                                await ref
                                    .read(emiRepositoryProvider)
                                    .markPaid(
                                      user.uid,
                                      e.planId,
                                      e.id,
                                    );
                                await ref
                                    .read(transactionRepositoryProvider)
                                    .create(
                                      userId: user.uid,
                                      title: 'EMI installment',
                                      amount: -e.installment.abs(),
                                      categoryId: 'EMI',
                                      date: e.dueDate,
                                      notes: 'EMI payment recorded from Home',
                                    );
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.emiMarkedPaidAdded ??
                                          'EMI marked paid and transaction added',
                                    ),
                                  ),
                                );
                              } catch (err) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Failed: $err')),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Text('Pay ${formatAmount(e.installment, currency)}'),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (i < items.take(3).length - 1) const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
