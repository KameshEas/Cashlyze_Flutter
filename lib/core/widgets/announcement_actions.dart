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

/// Runs an announcement's button.
Future<void> runAnnouncementCta(final WidgetRef ref, final AnnouncementInfo announcement) =>
    runCta(ref, announcement.ctaType, announcement.ctaValue);

/// Opens a link, goes to an in-app screen, or opens the store update page.
/// Shared by an announcement's button and a tapped push notification.
Future<void> runCta(final WidgetRef ref, final String? ctaType, final String? ctaValue) async {
  switch (ctaType) {
    case 'url':
      final uri = Uri.tryParse(ctaValue ?? '');
      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
    case 'route':
      if (ctaValue != null && ctaValue.startsWith('/')) {
        ref.read(appRouterProvider).go(ctaValue);
      }
    case 'store':
      final config = await ref.read(currentPlatformVersionProvider.future);
      final storeUrl = config?.storeUrl ?? '';
      if (storeUrl.isNotEmpty) await StoreRedirectService.openStoreFromUrl(storeUrl);
  }
}
