import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../core/utils/format.dart';
import '../../core/providers/shared_prefs_provider.dart';
import '../../core/repositories/budget_repository.dart';
import '../../core/repositories/category_repository.dart';
import 'transaction_filters.dart';

class TransactionFilterSheet extends ConsumerStatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  ConsumerState<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends ConsumerState<TransactionFilterSheet> {
  late String localFilter;
  late String localCategory;
  DateTime? localMonth;
  DateTime? localFromDate;
  DateTime? localToDate;
  late bool localUseDateRange;
  late TextEditingController minController;
  late TextEditingController maxController;

  @override
  void initState() {
    super.initState();
    final f = ref.read(transactionFilterProvider);
    localFilter = f.filter;
    localCategory = f.category;
    localMonth = f.selectedMonth;
    localFromDate = f.fromDate;
    localToDate = f.toDate;
    localUseDateRange = f.useDateRange;
    minController = TextEditingController(text: f.minAmount?.toString() ?? '');
    maxController = TextEditingController(text: f.maxAmount?.toString() ?? '');
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final catsAsync = ref.watch(userCategoriesProvider);
    final budgets = ref.watch(userBudgetsProvider).maybeWhen(data: (d) => d, orElse: () => const []);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 16, left: 12, right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Transactions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 16),

          // Period
          Text('Period', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 13,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return FilterChip(
                    label: const Text('All time'),
                    selected: localMonth == null,
                    onSelected: (_) => setState(() => localMonth = null),
                  );
                }
                final now = DateTime.now();
                final m = DateTime(now.year, now.month - (i - 1), 1);
                final label = '${m.year}-${m.month.toString().padLeft(2, '0')}';
                final isSelected = localMonth != null && localMonth!.year == m.year && localMonth!.month == m.month;
                return FilterChip(label: Text(label), selected: isSelected, onSelected: (_) => setState(() => localMonth = m));
              },
            ),
          ),
          const SizedBox(height: 20),

          // Date range
          Text('Date Range', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: localFromDate ?? DateTime.now().subtract(const Duration(days: 90)),
                      firstDate: DateTime.now().subtract(const Duration(days: 180)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        localFromDate = picked;
                        localUseDateRange = true;
                        if (localToDate != null && localFromDate!.isAfter(localToDate!)) localToDate = localFromDate;
                      });
                    }
                  },
                  child: Text(localUseDateRange && localFromDate != null
                      ? 'From: ${formatDate(localFromDate!, ref.watch(sharedPrefsServiceProvider).dateFormat)}'
                      : 'From'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: localToDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 180)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        localToDate = picked;
                        localUseDateRange = true;
                        if (localFromDate != null && localToDate!.isBefore(localFromDate!)) localFromDate = localToDate;
                      });
                    }
                  },
                  child: Text(localUseDateRange && localToDate != null
                      ? 'To: ${formatDate(localToDate!, ref.watch(sharedPrefsServiceProvider).dateFormat)}'
                      : 'To'),
                ),
              ),
              const SizedBox(width: 8),
              if (localUseDateRange)
                IconButton(
                  tooltip: 'Clear date range',
                  onPressed: () {
                    setState(() {
                      localUseDateRange = false;
                      localFromDate = null;
                      localToDate = null;
                    });
                    ref.read(transactionFilterProvider.notifier).setUseDateRange(false);
                  },
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),

          // Type
          Text('Type', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'All', label: Text(t?.filterAll ?? 'All')),
              ButtonSegment(value: 'Income', label: Text(t?.filterIncome ?? 'Income'), icon: const Icon(Icons.arrow_downward, size: 14)),
              ButtonSegment(value: 'Expense', label: Text(t?.filterExpense ?? 'Expense'), icon: const Icon(Icons.arrow_upward, size: 14)),
            ],
            selected: {localFilter},
            onSelectionChanged: (v) => setState(() => localFilter = v.first),
          ),
          const SizedBox(height: 20),

          // Category
          Text('Category', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          catsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final cats = <String>['All', 'General'];
              final seenLower = <String>{'all', 'general'};
              for (final c in list) {
                final nm = (c.name ?? '').trim();
                if (nm.isEmpty) continue;
                final nl = nm.toLowerCase();
                if (!seenLower.contains(nl)) {
                  cats.add(nm);
                  seenLower.add(nl);
                }
              }
              final idToName = <String, String>{};
              for (final c in list) {
                final nm = (c.name ?? '').trim();
                if (nm.isNotEmpty) idToName[c.id] = nm;
              }
              for (final b in budgets) {
                final catIds = b.categoryIds ?? <String>[];
                String key = '';
                if (catIds.isNotEmpty) {
                  final raw = catIds.first.trim();
                  if (raw.isEmpty) {
                    key = (b.name ?? '').trim();
                  } else if (idToName.containsKey(raw)) key = idToName[raw]!.trim();
                  else key = (b.name ?? raw).trim();
                } else {
                  key = (b.name ?? '').trim();
                }
                if (key.isEmpty) continue;
                final kl = key.toLowerCase();
                if (!seenLower.contains(kl)) {
                  cats.add(key);
                  seenLower.add(kl);
                }
              }

              return Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cats.map((c) => FilterChip(label: Text(c), selected: localCategory == c, onSelected: (_) => setState(() => localCategory = c))).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          // Amount range
          Text('Amount Range', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  decoration: const InputDecoration(labelText: 'Min', filled: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: maxController,
                  decoration: const InputDecoration(labelText: 'Max', filled: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(transactionFilterProvider.notifier).resetFilters();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final notifier = ref.read(transactionFilterProvider.notifier);
                    notifier.setFilterType(localFilter);
                    notifier.setCategory(localCategory);
                    notifier.setSelectedMonth(localMonth);
                    notifier.setUseDateRange(localUseDateRange);
                    if (localUseDateRange) {
                      notifier.setFromDate(localFromDate);
                      notifier.setToDate(localToDate);
                    } else {
                      notifier.setFromDate(null);
                      notifier.setToDate(null);
                    }
                    notifier.setMinAmount(double.tryParse(minController.text));
                    notifier.setMaxAmount(double.tryParse(maxController.text));
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
