import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

/// Resolves an Android deep link (a Helm-created `https://<domain>/l/{code}`
/// link) to the in-app path it should open, from either of the two ways one
/// can reach the app:
///
/// - Already installed: the OS hands the app the original https:// URL
///   directly (Android's App Links verification already matched it to this
///   app, no network request has happened yet). The destination isn't in
///   that URL - only Helm's backend knows it - so this asks the backend for
///   the redirect it *would* have sent a browser, without following it, and
///   reads the destination out of that redirect's own referrer parameter.
/// - Freshly installed from a link: the same destination survives the
///   install in the Play Store's install referrer (see push_service.py's
///   play_store_url_with_referrer on the backend), read here via
///   PlayInstallReferrer.
///
/// Both paths decode the same `deeplink_dest=<url-encoded-path>` shape, so
/// one parser (`_destinationFromReferrer`) serves both.
class DeepLinkService {
  DeepLinkService._();

  static final Dio _client = Dio(
    BaseOptions(followRedirects: false, validateStatus: (final status) => status != null && status < 400),
  );

  /// The in-app path an incoming `https://<domain>/l/{code}` URI should open,
  /// or null if it isn't one of ours, or it couldn't be resolved (offline,
  /// the code doesn't exist, the app isn't configured for it yet).
  static Future<String?> destinationForLink(final Uri uri) async {
    if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'l') return null;
    try {
      final response = await _client.getUri<void>(uri);
      final location = response.headers.value('location');
      return location == null ? null : _destinationFromRedirectUrl(location);
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
  /// (a sideloaded/dev build - expected, not an error).
  static Future<String?> destinationFromInstallReferrer() async {
    try {
      final details = await PlayInstallReferrer.installReferrer;
      final referrer = details.installReferrer;
      return referrer == null ? null : _destinationFromReferrer(referrer);
    } catch (e) {
      if (!kReleaseMode) debugPrint('Install referrer unavailable (expected outside Play Store installs): $e');
      return null;
    }
  }

  static String? _destinationFromRedirectUrl(final String redirectUrl) {
    final uri = Uri.tryParse(redirectUrl);
    final referrer = uri?.queryParameters['referrer'];
    return referrer == null ? null : _destinationFromReferrer(referrer);
  }

  /// `referrer` looks like "deeplink_dest=%2Fbudgets%2F123" - a single
  /// query-string-encoded field, already one level decoded by whoever handed
  /// it to us (the OS/Play for an install referrer; Uri.queryParameters for
  /// a redirect Location header).
  static String? _destinationFromReferrer(final String referrer) {
    final params = Uri.splitQueryString(referrer);
    final dest = params['deeplink_dest'];
    return (dest != null && dest.startsWith('/')) ? dest : null;
  }
}
