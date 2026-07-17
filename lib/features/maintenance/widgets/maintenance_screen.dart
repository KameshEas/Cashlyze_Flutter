import 'package:flutter/material.dart';

/// Full-screen, non-navigable notice shown when the backend has flagged the
/// app as under maintenance (see AppVersionModel.maintenanceMode). Replaces
/// the entire routed app content rather than being pushed as a route, so it
/// preempts login/navigation state entirely.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    required this.onRetry,
    super.key,
    this.message,
  });

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(final BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  'Under Maintenance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  (message == null || message!.isEmpty)
                      ? "We're making some improvements. Please check back shortly."
                      : message!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onRetry,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
