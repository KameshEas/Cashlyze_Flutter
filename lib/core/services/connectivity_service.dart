import 'dart:io';

/// Service to check network connectivity
class ConnectivityService {
  /// Check if device has network connectivity
  /// Uses DNS lookup as a reliable indicator of internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      // Try to reach a highly available DNS resolver
      final result = await InternetAddress.lookup('8.8.8.8', type: InternetAddressType.IPv4).timeout(
        const Duration(seconds: 2),
      );

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
