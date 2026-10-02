import 'package:flutter/material.dart';

import '../ui/motion.dart';

/// Dialog route with the app's dialog motion: "focus here before continuing".
/// A short scale (0.96 -> 1) plus fade over [AppDuration.component], and a
/// quicker exit. Reduced motion: no animation (duration zero).
///
/// Use instead of [showDialog] for new dialogs; Material's default is a bare
/// fade with no sense of arrival.
Future<T?> showAppDialog<T>({
  required final BuildContext context,
  required final WidgetBuilder builder,
  final bool barrierDismissible = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final reduce = reduceMotionOf(context);
  return navigator.push<T>(
    _AppDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      animationStyle: AnimationStyle(
        duration: reduce ? Duration.zero : AppDuration.component,
        reverseDuration: reduce ? Duration.zero : AppDuration.exitOf(AppDuration.component),
      ),
    ),
  );
}

class _AppDialogRoute<T> extends DialogRoute<T> {
  _AppDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
    super.themes,
    super.animationStyle,
  });

  @override
  Widget buildTransitions(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppCurve.standard,
      reverseCurve: AppCurve.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

Future<bool?> showConfirmDialog(final BuildContext context, {
  required final String title,
  required final String content,
  final String confirmLabel = 'Confirm',
  final String cancelLabel = 'Cancel',
}) {
  return showAppDialog<bool>(
    context: context,
    builder: (final ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(cancelLabel)),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
}

Future<String?> showInputDialog(final BuildContext context, {
  required final String title,
  required final String label,
  final bool obscure = false,
  final String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  try {
    final res = await showAppDialog<String?>(
      context: context,
      builder: (final ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    return res;
  } finally {
    controller.dispose();
  }
}
