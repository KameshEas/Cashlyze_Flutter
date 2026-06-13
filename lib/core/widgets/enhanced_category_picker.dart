import 'package:flutter/material.dart';

/// Enhanced category picker modal with search and favorites
class EnhancedCategoryPicker extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const EnhancedCategoryPicker({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  State<EnhancedCategoryPicker> createState() => _EnhancedCategoryPickerState();
}

class _EnhancedCategoryPickerState extends State<EnhancedCategoryPicker> {
  late TextEditingController _searchController;
  late Set<String> _favorites;
  List<String> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _favorites = {widget.selectedCategory};
    _updateFiltered();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFiltered() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredCategories = widget.categories;
    } else {
      _filteredCategories = widget.categories
          .where((cat) => cat.toLowerCase().contains(query))
          .toList();
    }
    setState(() {});
  }

  void _toggleFavorite(final String category) {
    setState(() {
      if (_favorites.contains(category)) {
        _favorites.remove(category);
      } else {
        _favorites.add(category);
      }
    });
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    // Separate into favorites and others
    final favorites =
        _filteredCategories.where((c) => _favorites.contains(c)).toList();
    final others =
        _filteredCategories.where((c) => !_favorites.contains(c)).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'Select Category',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _updateFiltered(),
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _updateFiltered();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Categories list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (favorites.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      'Favorites',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...favorites.map((final category) {
                    return _buildCategoryTile(
                      context,
                      category,
                      isFavorite: true,
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ],
                if (others.isNotEmpty) ...[
                  if (favorites.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'All Categories',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ...others.map((final category) {
                    return _buildCategoryTile(context, category);
                  }),
                ] else if (favorites.isEmpty && _filteredCategories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No categories found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    final BuildContext context,
    final String category, {
    final bool isFavorite = false,
  }) {
    final theme = Theme.of(context);
    final isSelected = category == widget.selectedCategory;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSelect(category);
          Navigator.pop(context, category);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: isSelected
                ? Border(
                    left: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 4,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                )
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 20,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _toggleFavorite(category),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _favorites.contains(category)
                          ? Icons.star
                          : Icons.star_outline,
                      color: _favorites.contains(category)
                          ? Colors.amber
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
