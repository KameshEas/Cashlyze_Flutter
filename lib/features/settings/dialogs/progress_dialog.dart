import 'package:flutter/material.dart';

/// Enhanced progress dialog for async operations (backup/restore)
class ProgressDialog extends StatelessWidget {

  const ProgressDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.itemCount,
    this.progress,
    this.estimatedTime,
    this.onCancel,
    this.showCancel = false,
  });
  final String title;
  final String? subtitle;
  final int? itemCount;
  final double? progress; // 0.0 to 1.0
  final String? estimatedTime;
  final void Function()? onCancel;
  final bool showCancel;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) ...[
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
            ],
            if (itemCount != null || progress != null) ...[
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: progress ?? 0.0,
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (itemCount != null)
                    Text(
                      '$itemCount items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  if (progress != null)
                    Text(
                      '${(progress! * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (estimatedTime != null)
                    Text(
                      'ETA: $estimatedTime',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(
                height: 64,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: showCancel
          ? [
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ]
          : [],
    );
  }
}
