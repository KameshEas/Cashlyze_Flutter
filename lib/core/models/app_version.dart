/// Platform type for version configuration
enum PlatformType {
  android('android'),
  ios('ios');

  final String value;
  const PlatformType(this.value);

  factory PlatformType.fromString(String value) {
    return PlatformType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlatformType.android,
    );
  }
}

/// App version model for managing forced updates
class AppVersionModel {
  final String minimumVersion;
  final String currentVersion;
  final String releaseNotes;
  final int rolloutPercentage;
  final String storeUrl;

  AppVersionModel({
    required this.minimumVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.rolloutPercentage,
    required this.storeUrl,
  });

  /// Create AppVersionModel from RTDB data
  factory AppVersionModel.fromRTDB(Map<String, dynamic> data) {
    return AppVersionModel(
      minimumVersion: data['minimumVersion'] ?? '0.0.0',
      currentVersion: data['currentVersion'] ?? '0.0.0',
      releaseNotes: data['releaseNotes'] ?? '',
      rolloutPercentage: (data['rolloutPercentage'] as num?)?.toInt() ?? 100,
      storeUrl: data['storeUrl'] ?? '',
    );
  }

  /// Convert AppVersionModel to RTDB format
  Map<String, dynamic> toRTDB() {
    return {
      'minimumVersion': minimumVersion,
      'currentVersion': currentVersion,
      'releaseNotes': releaseNotes,
      'rolloutPercentage': rolloutPercentage,
      'storeUrl': storeUrl,
    };
  }

  @override
  String toString() =>
      'AppVersionModel(min: $minimumVersion, current: $currentVersion, rollout: $rolloutPercentage%)';
}
