import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:flutter/services.dart' show rootBundle;

/// Reads `assets/aspire-services.json`, the client config downloaded from
/// Aspire Helm (like `google-services.json`).
///
/// Call [load] once at startup, before anything reads [EnvConfig.baseUrl].
/// If the file is missing or malformed, [apiBaseUrl] stays `null` and
/// [EnvConfig] falls back to its built-in URLs, so a bad file never blocks the app.
abstract final class AspireServicesConfig {
  static const String _assetPath = 'assets/aspire-services.json';

  static String? _apiBaseUrl;
  static String? _appName;

  /// Gateway root, e.g. `https://api.aspired2d.cloud` (no trailing slash).
  static String? get apiBaseUrl => _apiBaseUrl;

  /// App slug registered in Helm, e.g. `cashlyze`.
  static String? get appName => _appName;

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final baseUrl = (data['api_base_url'] as String?)?.trim();
      final appName = (data['app_name'] as String?)?.trim();
      if (baseUrl == null || baseUrl.isEmpty || appName == null || appName.isEmpty) {
        return;
      }
      _apiBaseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');
      _appName = appName;
    } catch (e) {
      if (!kReleaseMode) debugPrint('aspire-services.json not loaded: $e');
    }
  }
}
