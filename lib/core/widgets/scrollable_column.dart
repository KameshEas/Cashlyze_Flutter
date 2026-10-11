import 'package:flutter/material.dart';

/// A [Column] for bottom-sheet and dialog bodies that scrolls instead of
/// overflowing.
///
/// A plain `Column(mainAxisSize: MainAxisSize.min)` inside a modal sheet works
/// until its content gets taller than the space left: more fields, a larger
/// system font, a small phone, or the keyboard opening. Then Flutter paints the
/// yellow-black "BOTTOM OVERFLOWED BY n PIXELS" stripes and the bottom of the
/// sheet (usually the Save button) is unreachable. This shrink-wraps exactly
/// like the plain Column when everything fits, and scrolls when it doesn't.
class ScrollableColumn extends StatelessWidget {
  const ScrollableColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    // Kept so call sites that were `Column(mainAxisSize: MainAxisSize.min, ...)`
    // can swap the class name without touching their arguments. The column
    // always shrink-wraps; a scroll view needs that.
    // ignore: avoid_unused_constructor_parameters
    final MainAxisSize mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(final BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }
}
