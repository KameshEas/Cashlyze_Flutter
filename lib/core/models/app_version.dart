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

/// Maintenance details computed server-side (the device clock is never
/// trusted: [active] already accounts for the schedule and tester bypass).
class MaintenanceInfo {
  const MaintenanceInfo({
    this.active = false,
    this.isReadOnly = false,
    this.title,
    this.message,
    this.endsAt,
    this.retryAfterSeconds = 60,
    this.statusUrl,
  });

  factory MaintenanceInfo.fromJson(final Map<String, dynamic> data) {
    final retry = (data['retryAfterSeconds'] as num?)?.toInt() ?? 60;
    return MaintenanceInfo(
      active: data['active'] as bool? ?? false,
      isReadOnly: data['type'] == 'read_only',
      title: data['title'] as String?,
      message: data['message'] as String?,
      endsAt: DateTime.tryParse(data['endsAt'] as String? ?? ''),
      retryAfterSeconds: retry.clamp(15, 3600),
      statusUrl: data['statusUrl'] as String?,
    );
  }

  final bool active;

  /// `true` = usable but writes are disabled; `false` = full-screen block.
  final bool isReadOnly;
  final String? title;
  final String? message;
  final DateTime? endsAt;
  final int retryAfterSeconds;
  final String? statusUrl;
}

/// One live announcement, already chosen and ordered (highest priority first)
/// by the backend for this platform.
class AnnouncementInfo {
  const AnnouncementInfo({
    required this.id,
    required this.body,
    this.type = 'info',
    this.placement = 'banner',
    this.title,
    this.ctaLabel,
    this.ctaType,
    this.ctaValue,
    this.dismissible = true,
    this.frequency = 'once',
    this.priority = 0,
  });

  factory AnnouncementInfo.fromJson(final Map<String, dynamic> data) {
    return AnnouncementInfo(
      id: data['id'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'info',
      placement: data['placement'] as String? ?? 'banner',
      title: data['title'] as String?,
      ctaLabel: data['ctaLabel'] as String?,
      ctaType: data['ctaType'] as String?,
      ctaValue: data['ctaValue'] as String?,
      dismissible: data['dismissible'] as bool? ?? true,
      frequency: data['frequency'] as String? ?? 'once',
      priority: (data['priority'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String body;

  /// `info` | `success` | `warning` | `critical`
  final String type;

  /// `banner` | `dialog`
  final String placement;
  final String? title;
  final String? ctaLabel;

  /// `url` | `route` | `store`; null when there is no button.
  final String? ctaType;
  final String? ctaValue;
  final bool dismissible;

  /// `once` | `every_launch` | `daily`
  final String frequency;
  final int priority;

  bool get isBanner => placement != 'dialog';
  bool get isDialog => placement == 'dialog';
  bool get hasCta => ctaType != null && (ctaLabel?.isNotEmpty ?? false);
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
    this.maintenance = const MaintenanceInfo(),
    this.announcementActive = false,
    this.announcementMessage,
    this.announcements = const [],
    this.featureFlags = const {},
  });

  /// Create AppVersionModel from the backend's GET /app-version response.
  factory AppVersionModel.fromRTDB(final Map<String, dynamic> data) {
    final maintenanceMode = data['maintenanceMode'] as bool? ?? false;
    final maintenanceMessage = data['maintenanceMessage'] as String?;
    final maintenanceJson = data['maintenance'];
    final announcementActive = data['announcementActive'] as bool? ?? false;
    final announcementMessage = data['announcementMessage'] as String?;
    final announcementsJson = data['announcements'];
    return AppVersionModel(
      // Older backends only send the single-banner fields.
      announcements: announcementsJson is List
          ? announcementsJson
              .whereType<Map<String, dynamic>>()
              .map(AnnouncementInfo.fromJson)
              .where((final a) => a.id.isNotEmpty && a.body.isNotEmpty)
              .toList()
          : [
              if (announcementActive && (announcementMessage?.isNotEmpty ?? false))
                AnnouncementInfo(
                  id: 'legacy-${announcementMessage.hashCode}',
                  body: announcementMessage!,
                ),
            ],
      // Older backends only send the flat fields above.
      maintenance: maintenanceJson is Map<String, dynamic>
          ? MaintenanceInfo.fromJson(maintenanceJson)
          : MaintenanceInfo(active: maintenanceMode, message: maintenanceMessage),
      minimumVersion: data['minimumVersion'] ?? '0.0.0',
      currentVersion: data['currentVersion'] ?? '0.0.0',
      releaseNotes: data['releaseNotes'] ?? '',
      rolloutPercentage: (data['rolloutPercentage'] as num?)?.toInt() ?? 100,
      storeUrl: data['storeUrl'] ?? '',
      forceUpdate: data['forceUpdate'] as bool? ?? false,
      maintenanceMode: maintenanceMode,
      maintenanceMessage: maintenanceMessage,
      announcementActive: announcementActive,
      announcementMessage: announcementMessage,
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
  final MaintenanceInfo maintenance;
  final bool announcementActive;
  final String? announcementMessage;

  /// Live announcements for this platform, highest priority first.
  final List<AnnouncementInfo> announcements;
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
