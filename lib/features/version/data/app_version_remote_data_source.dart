import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/app_version.dart';

class AppVersionRemoteDataSource {
  const AppVersionRemoteDataSource(this._client);
  final ApiClient _client;

  /// [version] is the installed app version; the backend uses it to let
  /// allow-listed (e.g. QA) builds through maintenance and to target
  /// announcements. [locale] is the app language (e.g. `hi`) for translated
  /// announcements.
  Future<AppVersionModel?> getVersionByPlatform(
    final String platform, {
    final String? version,
    final String? locale,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.appVersion,
        queryParameters: {
          'platform': platform,
          if (version != null && version.isNotEmpty) 'version': version,
          if (locale != null && locale.isNotEmpty) 'locale': locale,
        },
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
