import 'package:flutter/material.dart';

/// Wrapper widget that adds pin and collapse/expand functionality to EMI cards
class EMICardWrapper extends StatefulWidget {
  final String planId;
  final Widget child;
  final bool canPin;
  final bool canCollapse;

  const EMICardWrapper({
    super.key,
    required this.planId,
    required this.child,
    this.canPin = true,
    this.canCollapse = true,
  });

  @override
  State<EMICardWrapper> createState() => _EMICardWrapperState();
}

class _EMICardWrapperState extends State<EMICardWrapper> {
  late bool _isPinned;
  late bool _isCollapsed;

  @override
  void initState() {
    super.initState();
    _isPinned = false;
    _isCollapsed = false;
  }

  void _togglePin() {
    setState(() => _isPinned = !_isPinned);
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_isPinned)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pin,
                  size: 14,
                  color: Colors.amber,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pinned',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPinned
                  ? Colors.amber.withValues(alpha: 0.3)
                  : theme.colorScheme.outline.withValues(alpha: 0.12),
              width: _isPinned ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.canCollapse)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleCollapse,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isCollapsed
                                ? Icons.expand_more
                                : Icons.expand_less,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: Container()),
                  if (widget.canPin)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _togglePin,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            _isPinned ? Icons.star : Icons.star_outline,
                            size: 20,
                            color: _isPinned ? Colors.amber : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Content (collapsed or expanded)
              if (!_isCollapsed) ...[
                const SizedBox(height: 8),
                widget.child,
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'EMI Details (tap to expand)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
