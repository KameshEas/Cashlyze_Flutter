import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/version/data/app_version_remote_data_source.dart';
import '../models/app_version.dart';

class AppVersionRepository {
  const AppVersionRepository(this._dataSource);
  final AppVersionRemoteDataSource _dataSource;

  Future<AppVersionModel?> getVersionByPlatform(
    final String platform, {
    final String? version,
    final String? locale,
  }) =>
      _dataSource.getVersionByPlatform(platform, version: version, locale: locale);
}

final appVersionRepositoryProvider = Provider<AppVersionRepository>((final ref) {
  return AppVersionRepository(ref.watch(appVersionRemoteDataSourceProvider));
});
