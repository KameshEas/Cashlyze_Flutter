import 'package:flutter/material.dart';

enum ProgressDialogType { backup, restore, export }

/// A customizable progress dialog with support for multiple steps and phases.
class EnhancedProgressDialog extends StatefulWidget {

  const EnhancedProgressDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.type = ProgressDialogType.backup,
    required this.progressStream,
    this.onCancel,
    this.canCancel = true,
    this.dismissDelay = const Duration(seconds: 2),
  });
  final String title;
  final String? subtitle;
  final ProgressDialogType type;
  final Stream<({String phase, double progress, String? errorMessage})>
      progressStream;
  final VoidCallback? onCancel;
  final bool canCancel;
  final Duration dismissDelay;

  static Future<void> show({
    required final BuildContext context,
    required final String title,
    final String? subtitle,
    final ProgressDialogType type = ProgressDialogType.backup,
    required final Stream<({String phase, double progress, String? errorMessage})>
        progressStream,
    final VoidCallback? onCancel,
    final bool canCancel = true,
    final Duration dismissDelay = const Duration(seconds: 2),
    final bool barrierDismissible = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => EnhancedProgressDialog(
        title: title,
        subtitle: subtitle,
        type: type,
        progressStream: progressStream,
        onCancel: onCancel,
        canCancel: canCancel,
        dismissDelay: dismissDelay,
      ),
    );
  }

  @override
  State<EnhancedProgressDialog> createState() => _EnhancedProgressDialogState();
}

class _EnhancedProgressDialogState extends State<EnhancedProgressDialog> {
  String _currentPhase = 'Initializing...';
  double _progress = 0.0;
  String? _errorMessage;
  bool _isComplete = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _listenToProgress();
  }

  void _listenToProgress() {
    widget.progressStream.listen(
      (final update) {
        if (!mounted) return;

        setState(() {
          _currentPhase = update.phase;
          _progress = update.progress.clamp(0.0, 1.0);
          _errorMessage = update.errorMessage;
          _hasError = update.errorMessage != null;

          // Mark as complete when progress reaches 1.0
          if (_progress >= 1.0 && !_hasError) {
            _isComplete = true;

            // Auto-dismiss after delay
            Future.delayed(widget.dismissDelay, () {
              if (mounted && _isComplete && !_hasError) {
                Navigator.of(context).pop();
              }
            });
          }
        });
      },
      onError: (final error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = error.toString();
        });
      },
    );
  }

  Color _getIconColor() {
    if (_hasError) return Colors.red;
    if (_isComplete) return Colors.green;
    return Colors.blue;
  }

  IconData _getIconData() {
    if (_hasError) return Icons.error;
    if (_isComplete) return Icons.check_circle;
    return Icons.cloud_sync;
  }

  @override
  Widget build(final BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Icon(_getIconData(), color: _getIconColor(), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title),
                if (widget.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasError
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Phase information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phase: $_currentPhase',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (widget.canCancel && !_isComplete)
          TextButton(
            onPressed: () {
              widget.onCancel?.call();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
        if (_isComplete || _hasError)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_hasError ? 'Close' : 'Done'),
          ),
      ],
    );
  }
}
