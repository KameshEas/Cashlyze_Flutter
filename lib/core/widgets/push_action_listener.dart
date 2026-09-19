import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_actions.dart';
import 'announcement_actions.dart';

/// Carries out the action of a tapped announcement push notification: opens
/// its link, goes to its in-app screen, or opens the store update page.
class PushActionListener extends ConsumerStatefulWidget {
  const PushActionListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushActionListener> createState() => _PushActionListenerState();
}

class _PushActionListenerState extends ConsumerState<PushActionListener> {
  StreamSubscription<PushAction>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = pushActionEvents.stream.listen(
      (final action) => runCta(ref, action.ctaType, action.ctaValue),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => widget.child;
}
