import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/models/search_result.dart';

final searchServiceProvider = Provider<SearchService>((final ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SearchService(apiClient);
});

class SearchService {
  SearchService(this._apiClient);
  final ApiClient _apiClient;

  Future<List<SearchResult>> search(
    final String query, {
    final int limit = 50,
  }) async {
    if (query.trim().length < 2) {
      return [];
    }

    try {
      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.search,
        queryParameters: {
          'q': query,
          'limit': limit,
        },
      );

      final List<dynamic> data = response.data ?? [];
      return data
          .map(
            (final e) => SearchResult.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(final String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final searchResultsProvider = FutureProvider<List<SearchResult>>((final ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().length < 2) {
    return [];
  }

  final service = ref.watch(searchServiceProvider);
  return service.search(query);
});
