import 'package:flutter/material.dart';

/// EMI status types
enum EMIStatus {
  paid('Paid', Colors.green),
  upcoming('Upcoming', Colors.blue),
  overdue('Overdue', Colors.red),
  dueToday('Due Today', Colors.orange);

  const EMIStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Determines EMI status based on due date and payment status
class EMIStatusHelper {
  static EMIStatus getStatus(final DateTime dueDate, final bool isPaid) {
    if (isPaid) return EMIStatus.paid;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDay == today) {
      return EMIStatus.dueToday;
    } else if (dueDay.isBefore(today)) {
      return EMIStatus.overdue;
    } else {
      return EMIStatus.upcoming;
    }
  }

  static int getDaysUntilDue(final DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.difference(today).inDays;
  }
}

/// Badge widget for displaying EMI status
class EMIStatusBadge extends StatelessWidget {

  const EMIStatusBadge({
    super.key,
    required this.status,
    this.daysUntilDue,
  });
  final EMIStatus status;
  final int? daysUntilDue;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = status.color.withValues(alpha: 0.15);
    final textColor = status.color;

    String displayText = status.label;
    if (daysUntilDue != null && status == EMIStatus.upcoming) {
      displayText = 'In $daysUntilDue days';
    } else if (daysUntilDue != null && status == EMIStatus.overdue) {
      displayText = '${daysUntilDue!.abs()} days overdue';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            displayText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large status indicator for detailed view
class EMIStatusIndicator extends StatelessWidget {

  const EMIStatusIndicator({
    super.key,
    required this.status,
    this.daysUntilDue,
    required this.isPaid,
  });
  final EMIStatus status;
  final int? daysUntilDue;
  final bool isPaid;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final color = status.color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (daysUntilDue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _getStatusDescription(status, daysUntilDue!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (status == EMIStatus.overdue) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Payment is overdue. Please pay as soon as possible.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon(final EMIStatus status) {
    return switch (status) {
      EMIStatus.paid => Icons.check_circle,
      EMIStatus.dueToday => Icons.schedule,
      EMIStatus.upcoming => Icons.calendar_today,
      EMIStatus.overdue => Icons.error,
    };
  }

  String _getStatusDescription(final EMIStatus status, final int days) {
    return switch (status) {
      EMIStatus.paid => 'Payment completed',
      EMIStatus.dueToday => 'Payment due today',
      EMIStatus.upcoming => 'Due in $days ${days == 1 ? 'day' : 'days'}',
      EMIStatus.overdue => '$days ${days == 1 ? 'day' : 'days'} overdue',
    };
  }
}
