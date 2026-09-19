import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/app_version.dart';

/// Query for GET /app-version.
///
/// [includeTest] asks the backend to also return the test announcements Helm's
/// "Add test announcements" button creates. Only debug builds send it, so real
/// users never see them.
Map<String, String> appVersionQuery(
  final String platform, {
  final String? version,
  final String? locale,
  final bool includeTest = false,
}) =>
    {
      'platform': platform,
      if (version != null && version.isNotEmpty) 'version': version,
      if (locale != null && locale.isNotEmpty) 'locale': locale,
      if (includeTest) 'test': 'true',
    };

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
        queryParameters: appVersionQuery(
          platform,
          version: version,
          locale: locale,
          includeTest: kDebugMode,
        ),
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
