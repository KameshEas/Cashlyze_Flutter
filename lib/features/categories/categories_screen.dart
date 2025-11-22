import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/category_repository.dart';
import '../../core/services/auth_service.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(userCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: catsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 72),
                  const SizedBox(height: 8),
                  const Text('No categories'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _openEdit(context, ref),
                    child: const Text('Add category'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (sepCtx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final c = list[i];
              return Container(
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
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openEdit(
                        context,
                        ref,
                        categoryId: c.id,
                        initialName: c.name,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Delete category'),
                            content: const Text(
                              'Are you sure you want to delete this category?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dCtx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dCtx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            final user = ref.read(currentUserProvider);
                            if (user == null) return;
                            await ref
                                .read(categoryRepositoryProvider)
                                .delete(user.uid, c.id);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Deleted')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref, {
    String? categoryId,
    String? initialName,
  }) async {
    final controller = TextEditingController(text: initialName ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final messenger = ScaffoldMessenger.of(ctx);
        return AlertDialog(
          title: Text(categoryId == null ? 'Add Category' : 'Edit Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty')),
                  );
                  return;
                }
                try {
                  final user = ref.read(currentUserProvider);
                  if (user == null) return;
                  final repo = ref.read(categoryRepositoryProvider);
                  final nav = Navigator.of(ctx);
                  if (categoryId == null) {
                    await repo.create(userId: user.uid, name: name);
                  } else {
                    await repo.update(user.uid, categoryId, {'name': name});
                  }
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Saved')),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }
}
