import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../routes/app_router.dart';
import '../providers/shared_prefs_provider.dart';
import '../services/deep_link_service.dart';

/// Routes an Android deep link (`https://<domain>/l/{code}`) to its in-app
/// destination - both a live click while the app is already running or
/// cold-starting, and (once, per install) a destination recovered from the
/// Play Store install referrer after installing from a link.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _appLinks.uriLinkStream.listen(_handleIncomingUri);
    unawaited(_checkInitialLink());
    unawaited(_checkInstallReferrerOnce());
  }

  Future<void> _checkInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri != null) await _handleIncomingUri(uri);
  }

  Future<void> _handleIncomingUri(final Uri uri) async {
    final destination = await DeepLinkService.destinationForLink(uri);
    if (!kReleaseMode) debugPrint('DeepLink: $uri -> ${destination ?? "(unresolved)"}');
    if (destination != null && mounted) ref.read(appRouterProvider).go(destination);
  }

  Future<void> _checkInstallReferrerOnce() async {
    final prefs = ref.read(sharedPrefsServiceProvider);
    if (prefs.installReferrerChecked) return;
    // Marked before the (network) check completes, not after: this must
    // never retry on a slow/failed call, since a genuinely fresh install
    // (no link involved) fails this check every time it's attempted.
    await prefs.markInstallReferrerChecked();
    final destination = await DeepLinkService.destinationFromInstallReferrer();
    if (destination != null && mounted) ref.read(appRouterProvider).go(destination);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => widget.child;
}
