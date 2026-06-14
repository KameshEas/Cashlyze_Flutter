import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';

/// Reusable utility for resolving between category IDs and names.
///
/// Eliminates the duplicated category id↔name resolution logic that was
/// previously copied across 5+ different files (home_screen, budget_providers,
/// budget_repository, transaction_ingest_service, etc.).
///
/// Usage:
/// ```dart
/// final resolver = CategoryResolver(categories);
/// final displayName = resolver.resolveDisplayName(tx.categoryId, tx.categoryName);
/// ```
@immutable
class CategoryResolver {
  CategoryResolver(this.categories)
      : _idToName = _buildIdToName(categories),
        _nameToIds = _buildNameToIds(categories);

  /// The full list of user categories.
  final List<CategoryModel> categories;

  /// Pre-built lookup maps.
  final Map<String, String> _idToName;
  final Map<String, Set<String>> _nameToIds;

  /// Returns the display name for the given category id or name.
  ///
  /// Resolution priority:
  /// 1. Match by category id → return the category's name
  /// 2. Match by categoryName (fallback) → return the matched category's name
  /// 3. Return categoryName if provided and no match found
  /// 4. Return categoryId if provided and no match found
  /// 5. Return 'General' if nothing provided
  String resolveDisplayName(String? categoryId, String? categoryName) {
    final id = categoryId?.trim();
    final nameFallback = categoryName?.trim();

    if ((id == null || id.isEmpty) && (nameFallback == null || nameFallback.isEmpty)) {
      return 'General';
    }

    // Try by ID first
    if (id != null && id.isNotEmpty) {
      final byId = _idToName[id];
      if (byId != null) {
        // If categoryName differs from the resolved name, prefer the explicit name
        if (nameFallback != null && nameFallback.isNotEmpty &&
            byId.toLowerCase() != nameFallback.toLowerCase()) {
          return nameFallback;
        }
        return byId;
      }
      // ID not found, try matching as name
      final lookup = nameFallback ?? id;
      final matchedIds = _nameToIds[lookup.toLowerCase()];
      if (matchedIds != null && matchedIds.isNotEmpty) {
        return _idToName[matchedIds.first] ?? lookup;
      }
      if (nameFallback != null && nameFallback.isNotEmpty) {
        return nameFallback;
      }
      return id;
    }

    // No ID, but have a name fallback
    final lookup = nameFallback!.trim();
    final matchedIds = _nameToIds[lookup.toLowerCase()];
    return matchedIds != null && matchedIds.isNotEmpty
        ? _idToName[matchedIds.first] ?? lookup
        : lookup;
  }

  /// Maps a category id to its display name.
  String? idToName(String? id) {
    if (id == null || id.isEmpty) return null;
    return _idToName[id.trim()];
  }

  /// Returns all category IDs matching the given name (case-insensitive).
  Set<String> nameToIds(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const <String>{};
    return _nameToIds[trimmed.toLowerCase()] ?? const <String>{};
  }

  /// Checks if a category ID or name string matches any budget-associated category.
  bool matchesAny(String value, Iterable<String> budgetCategoryIds) {
    final v = value.trim().toLowerCase();
    for (final bId in budgetCategoryIds) {
      if (bId.trim().toLowerCase() == v) return true;
    }
    return false;
  }

  // ── Private ──────────────────────────────────────────────────────────────

  static Map<String, String> _buildIdToName(List<CategoryModel> categories) {
    final map = <String, String>{};
    for (final c in categories) {
      final nameTrim = (c.name).trim();
      map[c.id] = nameTrim;
    }
    return map;
  }

  static Map<String, Set<String>> _buildNameToIds(List<CategoryModel> categories) {
    final map = <String, Set<String>>{};
    for (final c in categories) {
      final nameTrim = (c.name).trim();
      final key = nameTrim.toLowerCase();
      map.putIfAbsent(key, () => <String>{}).add(c.id);
    }
    return map;
  }
}

/// Provider for [CategoryResolver].
///
/// Automatically rebuilds when categories change.
final categoryResolverProvider = Provider.family<CategoryResolver, List<CategoryModel>>(
  (ref, categories) => CategoryResolver(categories),
);