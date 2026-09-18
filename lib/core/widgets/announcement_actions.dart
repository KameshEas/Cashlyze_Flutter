import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routes/app_router.dart';
import '../models/app_version.dart';
import '../providers/app_version_providers.dart';
import '../services/store_redirect_service.dart';

/// Colours and icon for an announcement `type`, themed so they read well in
/// both light and dark mode.
({Color accent, IconData icon}) announcementStyle(
  final ColorScheme colorScheme,
  final String type,
) {
  return switch (type) {
    'success' => (accent: Colors.green.shade600, icon: Icons.check_circle_outline_rounded),
    'warning' => (accent: Colors.orange.shade700, icon: Icons.warning_amber_rounded),
    'critical' => (accent: colorScheme.error, icon: Icons.error_outline_rounded),
    _ => (accent: colorScheme.primary, icon: Icons.campaign_outlined),
  };
}

/// Runs an announcement's button: open a link, go to an in-app screen, or
/// open the store update page.
Future<void> runAnnouncementCta(final WidgetRef ref, final AnnouncementInfo announcement) async {
  switch (announcement.ctaType) {
    case 'url':
      final uri = Uri.tryParse(announcement.ctaValue ?? '');
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    case 'route':
      final route = announcement.ctaValue;
      if (route != null && route.startsWith('/')) {
        ref.read(appRouterProvider).go(route);
      }
    case 'store':
      final config = await ref.read(currentPlatformVersionProvider.future);
      final storeUrl = config?.storeUrl ?? '';
      if (storeUrl.isNotEmpty) await StoreRedirectService.openStoreFromUrl(storeUrl);
  }
}
