/// Platform type for version configuration
enum PlatformType {
  android('android'),
  ios('ios');

  const PlatformType(this.value);

  factory PlatformType.fromString(final String value) {
    return PlatformType.values.firstWhere(
      (final e) => e.value == value,
      orElse: () => PlatformType.android,
    );
  }

  final String value;
}

/// App version model for managing forced updates
class AppVersionModel {

  AppVersionModel({
    required this.minimumVersion,
    required this.currentVersion,
    required this.releaseNotes,
    required this.rolloutPercentage,
    required this.storeUrl,
    this.forceUpdate = false,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.announcementActive = false,
    this.announcementMessage,
    this.featureFlags = const {},
  });

  /// Create AppVersionModel from the backend's GET /app-version response.
  factory AppVersionModel.fromRTDB(final Map<String, dynamic> data) {
    return AppVersionModel(
      minimumVersion: data['minimumVersion'] ?? '0.0.0',
      currentVersion: data['currentVersion'] ?? '0.0.0',
      releaseNotes: data['releaseNotes'] ?? '',
      rolloutPercentage: (data['rolloutPercentage'] as num?)?.toInt() ?? 100,
      storeUrl: data['storeUrl'] ?? '',
      forceUpdate: data['forceUpdate'] as bool? ?? false,
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: data['maintenanceMessage'] as String?,
      announcementActive: data['announcementActive'] as bool? ?? false,
      announcementMessage: data['announcementMessage'] as String?,
      featureFlags: (data['featureFlags'] as Map<String, dynamic>?)?.map(
            (final key, final value) => MapEntry(key, value == true),
          ) ??
          const {},
    );
  }
  final String minimumVersion;
  final String currentVersion;
  final String releaseNotes;
  final int rolloutPercentage;
  final String storeUrl;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final bool announcementActive;
  final String? announcementMessage;
  final Map<String, bool> featureFlags;

  /// Convert AppVersionModel back to the backend's wire format.
  Map<String, dynamic> toRTDB() {
    return {
      'minimumVersion': minimumVersion,
      'currentVersion': currentVersion,
      'releaseNotes': releaseNotes,
      'rolloutPercentage': rolloutPercentage,
      'storeUrl': storeUrl,
      'forceUpdate': forceUpdate,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'announcementActive': announcementActive,
      'announcementMessage': announcementMessage,
      'featureFlags': featureFlags,
    };
  }

  @override
  String toString() =>
      'AppVersionModel(min: $minimumVersion, current: $currentVersion, rollout: $rolloutPercentage%, '
      'maintenance: $maintenanceMode, announcement: $announcementActive, flags: $featureFlags)';
}
