import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_prefs_provider.dart';
import '../services/offline_cache_service.dart';

/// Provider for OfflineCacheService
final offlineCacheServiceProvider = Provider<OfflineCacheService>((final ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return OfflineCacheService(prefs);
});
