import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/search_result.dart';
import '../../core/providers/search_providers.dart';
import '../../core/ui/motion.dart';
import '../../core/utils/repo_error_handler.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/skeleton.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        elevation: 0,
      ),
      body: const SearchBody(),
    );
  }
}

class SearchBody extends ConsumerStatefulWidget {
  const SearchBody({super.key});

  @override
  ConsumerState<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<SearchBody> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(searchQueryProvider.notifier).setQuery(_searchController.text);
  }

  @override
  Widget build(final BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search transactions, budgets, goals...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            autofocus: true,
          ),
        ),
        Expanded(
          child: searchResultsAsync.when(
            data: (final results) {
              if (_searchController.text.trim().isEmpty) {
                return const Center(
                  child: AppEmptyState(
                    title: 'Start typing to search',
                    icon: Icons.search_outlined,
                  ),
                );
              }

              if (results.isEmpty) {
                return const Center(
                  child: AppEmptyState(
                    title: 'No results found',
                    icon: Icons.search_off_outlined,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: results.length,
                itemBuilder: (final context, final index) {
                  final result = results[index];
                  return MotionFadeIn(
                    delay: MotionStagger.delayFor(index),
                    child: SearchResultTile(
                      result: result,
                      onTap: () => _handleResultTap(context, result),
                    ),
                  );
                },
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (final context, final i) => const SkeletonListTile(),
              separatorBuilder: (final context, final i) => const SizedBox(height: 8),
              itemCount: 6,
            ),
            error: (final err, final stack) => Center(
              child: AppEmptyState(
                title: 'Failed to search',
                subtitle: repoErrorMessage(err),
                icon: Icons.error_outline_rounded,
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(searchResultsProvider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleResultTap(final BuildContext context, final SearchResult result) {
    switch (result.entityType) {
      case 'transaction':
        Navigator.pop(context);
        // Could navigate to transaction detail, but for now just close
        break;
      case 'category':
        Navigator.pop(context);
        break;
      case 'budget':
        Navigator.pop(context);
        GoRouter.of(context).go('/budgets');
        break;
      case 'savings_goal':
        Navigator.pop(context);
        GoRouter.of(context).go('/goals');
        break;
    }
  }
}

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    required this.result,
    required this.onTap,
    super.key,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    result.displayIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      result.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            result.displayType,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
