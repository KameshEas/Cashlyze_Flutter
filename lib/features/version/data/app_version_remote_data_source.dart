import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/app_version.dart';

class AppVersionRemoteDataSource {
  const AppVersionRemoteDataSource(this._client);
  final ApiClient _client;

  Future<AppVersionModel?> getVersionByPlatform(final String platform) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.appVersion,
        queryParameters: {'platform': platform},
      );
      final data = response.data;
      if (data == null) return null;
      return AppVersionModel.fromRTDB(data);
    } catch (_) {
      return null;
    }
  }
}

final appVersionRemoteDataSourceProvider =
    Provider<AppVersionRemoteDataSource>((final ref) {
  return AppVersionRemoteDataSource(ref.watch(apiClientProvider));
});
