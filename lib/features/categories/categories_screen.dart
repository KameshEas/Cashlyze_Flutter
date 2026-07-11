import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/category.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final catsAsync = ref.watch(userCategoriesProvider);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t?.manageCategoriesTitle ?? 'Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(t?.add ?? 'Add'),
      ),
      body: catsAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (final context, final i) => const SkeletonListTile(),
          separatorBuilder: (final context, final i) => const SizedBox(height: 8),
          itemCount: 6,
        ),
        error: (final e, _) => Center(
          child: AppEmptyState(
            title: 'Failed to load categories',
            subtitle: repoErrorMessage(e),
            icon: Icons.error_outline_rounded,
            actionLabel: t?.retry ?? 'Retry',
            onAction: () => ref.invalidate(userCategoriesProvider),
          ),
        ),
        data: (final list) {
          if (list.isEmpty) {
            return Center(
              child: AppEmptyState(
                title: t?.noCategories ?? 'No categories',
                icon: Icons.category_outlined,
                actionLabel: t?.addCategory ?? 'Add category',
                onAction: () => _openEdit(context, ref),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (final sepCtx, final i) => const SizedBox(height: 8),
            itemBuilder: (final ctx, final i) {
              final c = list[i];
              return MotionFadeIn(
                delay: MotionStagger.delayFor(i),
                child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.label_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name)),
                    IconButton(
                      tooltip: t?.edit ?? 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEdit(
                        context,
                        ref,
                        categoryId: c.id,
                        initialName: c.name,
                      ),
                    ),
                    IconButton(
                      tooltip: t?.delete ?? 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showConfirmDialog(
                          context,
                          title: t?.deleteCategoryTitle ?? 'Delete category',
                          content: t?.deleteCategoryConfirm ?? 'Are you sure you want to delete this category?',
                          confirmLabel: t?.delete ?? 'Delete',
                          cancelLabel: t?.cancel ?? 'Cancel',
                        );
                        if (confirm == true) {
                          try {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;
                            await ref
                                .read(categoryRepositoryProvider)
                                .delete(user.uid, c.id);
                            // Force a refresh of categories so UI doesn't show cached values
                            try {
                              ref.invalidate(userCategoriesProvider);
                            } catch (_) {}
                            messenger.showSnackBar(
                              SnackBar(content: Text(t?.deleted ?? 'Deleted')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(repoErrorMessage(e))),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ));
            },
          );
        },
      ),
    );
  }

  Future<void> _openEdit(
    final BuildContext context,
    final WidgetRef ref, {
    final String? categoryId,
    final String? initialName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final name = await showInputDialog(
      context,
      title: categoryId == null
          ? (AppLocalizations.of(context)?.addCategoryTitle ?? 'Add Category')
          : (AppLocalizations.of(context)?.editCategoryTitle ?? 'Edit Category'),
      label: AppLocalizations.of(context)?.nameLabel ?? 'Name',
      initial: initialName ?? '',
    );
    if (name == null) return;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.nameEmptyError ?? 'Name cannot be empty')),
      );
      return;
    }
    final existing = ref.read(userCategoriesProvider).maybeWhen(
          data: (final list) => list,
          orElse: () => const <CategoryModel>[],
        );
    final isDuplicate = existing.any(
      (final c) => c.id != categoryId && c.name.toLowerCase() == trimmedName.toLowerCase(),
    );
    if (isDuplicate) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n?.nameDuplicateError ?? 'A category with this name already exists')),
      );
      return;
    }
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final repo = ref.read(categoryRepositoryProvider);
      if (categoryId == null) {
        await repo.create(userId: user.uid, name: name.trim());
      } else {
        await repo.update(user.uid, categoryId, {'name': name.trim()});
      }
      // Ensure the provider refreshes so the list reflects the change
      try {
        ref.invalidate(userCategoriesProvider);
      } catch (_) {}
      messenger.showSnackBar(SnackBar(content: Text(l10n?.saved ?? 'Saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(repoErrorMessage(e))));
    }
  }
}
