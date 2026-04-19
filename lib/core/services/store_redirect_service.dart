import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class StoreRedirectService {
  /// Open Play Store for Android
  static Future<bool> openPlayStore({
    required String packageName,
    String? appName,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      // Try deep link first
      final deepLink = Uri(
        scheme: 'market',
        host: 'details',
        queryParameters: {'id': packageName},
      );

      if (await canLaunchUrl(deepLink)) {
        return await launchUrl(deepLink);
      }

      // Fallback to web URL
      final webUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=$packageName',
      );

      if (await canLaunchUrl(webUrl)) {
        return await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error opening Play Store: $e');
      return false;
    }
  }

  /// Open App Store for iOS
  static Future<bool> openAppStore({
    required String appId,
    String? appName,
  }) async {
    if (!Platform.isIOS) return false;

    try {
      // Try App Store deep link
      final deepLink = Uri.parse('itms-apps://apps.apple.com/app/$appId');

      if (await canLaunchUrl(deepLink)) {
        return await launchUrl(deepLink);
      }

      // Fallback to web URL
      final webUrl = Uri.parse('https://apps.apple.com/app/$appId');

      if (await canLaunchUrl(webUrl)) {
        return await launchUrl(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
      }

      return false;
    } catch (e) {
      debugPrint('Error opening App Store: $e');
      return false;
    }
  }

  /// Open store based on platform
  /// For Android, pass packageName (e.g., 'com.cashlyze.app')
  /// For iOS, pass appId (e.g., '1234567890')
  static Future<bool> openStore({
    String? androidPackageName,
    String? iosAppId,
    String? appName,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }

    if (Platform.isAndroid && androidPackageName != null) {
      return openPlayStore(packageName: androidPackageName, appName: appName);
    }

    if (Platform.isIOS && iosAppId != null) {
      return openAppStore(appId: iosAppId, appName: appName);
    }

    return false;
  }

  /// Open store using direct URLs (fallback method)
  static Future<bool> openStoreFromUrl(String storeUrl) async {
    try {
      final url = Uri.parse(storeUrl);
      if (await canLaunchUrl(url)) {
        return await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      debugPrint('Error opening store URL: $e');
      return false;
    }
  }
}
