import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/app_version.dart';

/// Full-screen, non-navigable notice shown when the backend has flagged the
/// app as under maintenance (see [MaintenanceInfo]). Replaces the entire
/// routed app content rather than being pushed as a route, so it preempts
/// login/navigation state entirely.
///
/// Re-checks on its own every [MaintenanceInfo.retryAfterSeconds], so users
/// are let back in without having to press anything.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({
    required this.onRetry,
    super.key,
    this.info = const MaintenanceInfo(),
  });

  final MaintenanceInfo info;
  final VoidCallback onRetry;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(final MaintenanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info.retryAfterSeconds != widget.info.retryAfterSeconds) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: widget.info.retryAfterSeconds),
      (final _) => widget.onRetry(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openStatusPage(final String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final info = widget.info;
    final title = (info.title == null || info.title!.isEmpty)
        ? 'Under Maintenance'
        : info.title!;
    final message = (info.message == null || info.message!.isEmpty)
        ? "We're making some improvements. Please check back shortly."
        : info.message!;
    final endsAt = info.endsAt;
    final statusUrl = info.statusUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.secondary.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    Icons.build_rounded,
                    size: 48,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                if (endsAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Expected back ${DateFormat.MMMd().add_jm().format(endsAt.toLocal())}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: widget.onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Try Again'),
                  ),
                ),
                if (statusUrl != null && statusUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _openStatusPage(statusUrl),
                    child: const Text('View status page'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
