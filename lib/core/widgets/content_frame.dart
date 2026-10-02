import 'package:flutter/material.dart';

/// Keeps content at a comfortable reading width on tablets and large phones
/// in landscape, instead of stretching the phone layout edge to edge.
///
/// Phones (narrower than [maxWidth]) are unaffected. Wider windows get a
/// centred column on the scaffold colour. Wrap the app's routed content once
/// (MaterialApp.builder), so pages, dialogs and sheets all share the frame.
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = defaultMaxWidth});

  final Widget child;
  final double maxWidth;

  /// ~ medium window class: wide enough for a tablet portrait column.
  static const double defaultMaxWidth = 640;

  @override
  Widget build(final BuildContext context) {
    return LayoutBuilder(
      builder: (final context, final constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth <= maxWidth) return child;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
