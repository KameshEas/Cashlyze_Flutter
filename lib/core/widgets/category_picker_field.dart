import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../repositories/budget_repository.dart';
import '../repositories/category_repository.dart';

class CategoryPickerField extends ConsumerWidget {

  const CategoryPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.heightFactor = 0.6,
    this.budgetsOnly = false,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;
  final double heightFactor;
  final bool budgetsOnly;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final theme = Theme.of(context);
    final catsAsync = ref.watch(userCategoriesProvider);
    final budgetsAsync = ref.watch(userBudgetsProvider);

    List<String> categoryNames = [];

    if (budgetsOnly) {
      final budgets = budgetsAsync.maybeWhen(data: (final d) => d, orElse: () => const <BudgetModel>[]);
      final Map<String, String> uniqueByName = {};
      for (final b in budgets) {
        final name = b.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        uniqueByName.putIfAbsent(key, () => name);
      }
      categoryNames = uniqueByName.values.toList();
    } else {
      final Map<String, String> unique = {'general': 'General'};

      catsAsync.when(
        loading: () {},
        error: (final dynamic error, final StackTrace stack) {},
        data: (final list) {
          for (final c in list) {
            final name = (c.name).trim();
            if (name.isEmpty) continue;
            final key = name.toLowerCase();
            if (!unique.containsKey(key)) unique[key] = name;
          }
        },
      );

      budgetsAsync.when(
        loading: () {},
        error: (final dynamic error, final StackTrace stack) {},
        data: (final list) {
          for (final b in list) {
            final name = (b.name).trim();
            if (name.isEmpty) continue;
            final key = name.toLowerCase();
            if (!unique.containsKey(key)) unique[key] = name;
          }
        },
      );

      categoryNames = unique.values.toList();
    }
    final safeValue = categoryNames.contains(value) ? value : (categoryNames.isNotEmpty ? categoryNames.first : 'General');

    return InkWell(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (final BuildContext sheetCtx) {
            return SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * heightFactor,
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
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: categoryNames.length,
                      separatorBuilder: (final BuildContext ctx, final int idx) => const Divider(height: 1),
                      itemBuilder: (final BuildContext cctx, final int i) {
                        final name = categoryNames[i];
                        return ListTile(
                          title: Text(name, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.of(cctx).pop(name),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label ?? 'Category', filled: true),
        isEmpty: safeValue.isEmpty,
        child: Row(
          children: [
            Expanded(child: Text(safeValue, overflow: TextOverflow.ellipsis)),
            Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
          ],
        ),
      ),
    );
  }
}
