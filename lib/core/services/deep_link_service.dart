import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

/// Resolves a Helm-created `https://<domain>/l/{code}` deep link to the
/// in-app path it should open, from either of the two ways one can reach
/// the app:
///
/// - Already installed: the OS hands the app the original https:// URL
///   directly (App Links on Android / Universal Links on iOS already
///   matched it to this app - no network request has happened yet). The
///   destination isn't in that URL - only Helm's backend knows it - so this
///   asks the backend directly via `/l/{code}/open`, which exists precisely
///   for this case (unlike the plain `/l/{code}` redirect, it needs no
///   User-Agent guessing: the app already knows its own platform).
/// - Freshly installed from an Android link: the destination survives the
///   install in the Play Store's install referrer (see
///   play_store_url_with_referrer on the backend), read here via
///   PlayInstallReferrer. iOS has no install-time equivalent - a
///   not-yet-installed iOS click can only land on the App Store.
class DeepLinkService {
  DeepLinkService._();

  static final Dio _client = Dio();

  /// The in-app path an incoming `https://<domain>/l/{code}` URI should open,
  /// or null if it isn't one of ours, or it couldn't be resolved (offline,
  /// the code doesn't exist or has expired).
  static Future<String?> destinationForLink(final Uri uri) async {
    if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'l') return null;
    final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : null);
    final openUri = uri.replace(
      path: '${uri.path}/open',
      queryParameters: platform == null ? null : {'platform': platform},
    );
    try {
      final response = await _client.getUri<Map<String, dynamic>>(openUri);
      final dest = response.data?['destination_path'] as String?;
      return (dest != null && dest.startsWith('/')) ? dest : null;
    } catch (e) {
      if (!kReleaseMode) debugPrint('Deep link resolution failed for $uri: $e');
      return null;
    }
  }

  /// The in-app path a not-yet-installed click on one of our links was
  /// headed to, read back from the Play Store's install referrer - but only
  /// ever attempted once per install (callers gate this via
  /// SharedPrefsService.installReferrerChecked; a fresh install genuinely
  /// has no referrer to read here). Returns null when there's nothing to
  /// recover: not installed from a link, or Play services aren't available
  /// (a sideloaded/dev build, or iOS - expected, not an error).
  static Future<String?> destinationFromInstallReferrer() async {
    if (!Platform.isAndroid) return null;
    try {
      final details = await PlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      if (referrer == null) return null;
      // "deeplink_dest=%2Fbudgets%2F123..." - a single query-string-encoded
      // field, already one level decoded by the OS by the time it reaches us.
      final dest = Uri.splitQueryString(referrer)['deeplink_dest'];
      return (dest != null && dest.startsWith('/')) ? dest : null;
    } catch (e) {
      if (!kReleaseMode) debugPrint('Install referrer unavailable (expected outside Play Store installs): $e');
      return null;
    }
  }
}
