import 'dart:async';

import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// MOTION SYSTEM  —  minimalistic, Apple-like animation primitives.
///
/// One file, multiple ways to animate. Everything here is dependency-free
/// (Flutter `material` only) and automatically respects the platform's
/// "reduce motion" accessibility setting (`MediaQuery.disableAnimations`),
/// collapsing to an instant, non-animated result when enabled.
///
/// Quick reference:
///   • MotionFadeIn   — one-shot entrance (fade + slide + subtle scale)
///   • MotionStagger  — cascade a Column/Row of children in sequence
///   • PressableScale — iOS-style press-to-shrink tap feedback
///   • MotionSwitcher — smooth fade+scale swap between two widgets
///   • AppMotion.fadeThrough — peer / system-state route transition
///   • AppMotion.sharedAxisX — parent -> child route transition
///   • AppMotion.riseIn      — task / creation flow route transition
/// ─────────────────────────────────────────────────────────────────────────

/// Standard motion durations. Apple UIs favour short, confident timings.
abstract final class AppDuration {
  /// No animation.
  static const Duration instant = Duration.zero;

  /// Micro-interactions: taps, toggles, hovers.
  static const Duration fast = Duration(milliseconds: 200);

  /// The default — entrances, content swaps, most transitions.
  static const Duration normal = Duration(milliseconds: 350);

  /// Emphasized / larger surfaces (sheets, hero elements).
  static const Duration slow = Duration(milliseconds: 500);

  /// Route (page) transitions.
  static const Duration page = Duration(milliseconds: 350);

  /// Delay added per item in a staggered sequence.
  static const Duration stagger = Duration(milliseconds: 60);

  // ── Motion tiers (docs/redesign/08) ─────────────────────────────────────
  // Level 1 micro 100-200ms, Level 2 component 180-350ms, Level 3 screen
  // 250-500ms. `fast`/`normal`/`slow` above sit inside these ranges.

  /// Level 1: press, toggle, focus, hover, validation.
  static const Duration micro = Duration(milliseconds: 120);

  /// Level 2: dialog, sheet, dropdown, expand/collapse, tab content.
  static const Duration component = Duration(milliseconds: 260);

  /// Level 3: route changes with spatial meaning (shared-axis / rise).
  static const Duration screen = Duration(milliseconds: 320);

  /// Exits run at this fraction of their enter duration: quick, controlled,
  /// out of the way.
  static const double exitFactor = 0.7;

  /// The exit duration matching an enter [d].
  static Duration exitOf(final Duration d) =>
      Duration(microseconds: (d.inMicroseconds * exitFactor).round());
}

/// Apple-like easing curves — smooth deceleration, no springy bounce.
abstract final class AppCurve {
  /// Entrances and most "appear" motion (decelerate into place).
  static const Curve standard = Curves.easeOutCubic;

  /// Two-sided transitions (move A → B).
  static const Curve emphasized = Curves.easeInOutCubic;

  /// Strong settle — good for values landing into place.
  static const Curve decelerate = Curves.easeOutQuart;

  /// A *restrained* pop. Use sparingly for playful accents.
  static const Curve gentlePop = Curves.easeOutBack;

  /// Press / release feedback.
  static const Curve tap = Curves.easeOut;

  /// Exits and dismissals: accelerate away, don't linger.
  static const Curve exit = Curves.easeInCubic;
}

/// Returns true when the user has requested reduced motion.
bool reduceMotionOf(final BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// ─────────────────────────────────────────────────────────────────────────
/// MotionFadeIn — a one-shot entrance animation.
///
/// Fades in while optionally sliding from an offset and scaling up from
/// [beginScale]. Plays once when first mounted, after an optional [delay]
/// (use [delay] to build staggered sequences manually).
///
/// ```dart
/// MotionFadeIn(child: MyCard())
/// MotionFadeIn(delay: AppDuration.stagger * 2, slideY: 16, child: Text('Hi'))
/// ```
/// ─────────────────────────────────────────────────────────────────────────
class MotionFadeIn extends StatefulWidget {
  const MotionFadeIn({
    super.key,
    required this.child,
    this.duration = AppDuration.normal,
    this.delay = Duration.zero,
    this.curve = AppCurve.standard,
    this.slideY = 12.0,
    this.slideX = 0.0,
    this.beginScale = 1.0,
    this.enabled = true,
  });

  final Widget child;

  /// How long the entrance takes.
  final Duration duration;

  /// Wait this long before starting (used for staggering).
  final Duration delay;

  final Curve curve;

  /// Vertical offset (logical px) to slide up from. Positive = starts below.
  final double slideY;

  /// Horizontal offset (logical px) to slide from. Positive = starts right.
  final double slideX;

  /// Initial scale (1.0 disables scaling). 0.96–0.98 reads as a subtle lift.
  final double beginScale;

  /// When false, the child is shown immediately with no animation.
  final bool enabled;

  @override
  State<MotionFadeIn> createState() => _MotionFadeInState();
}

class _MotionFadeInState extends State<MotionFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _startTimer;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is available here; schedule the entrance exactly once.
    if (_scheduled) return;
    _scheduled = true;

    if (!widget.enabled || reduceMotionOf(context)) {
      _controller.value = 1.0;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _startTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (final context, final child) {
        final t = widget.curve.transform(_controller.value);
        Widget result = Opacity(opacity: t.clamp(0.0, 1.0), child: child);

        if (widget.beginScale != 1.0) {
          final scale = widget.beginScale + (1.0 - widget.beginScale) * t;
          result = Transform.scale(scale: scale, child: result);
        }

        final dx = widget.slideX * (1.0 - t);
        final dy = widget.slideY * (1.0 - t);
        if (dx != 0.0 || dy != 0.0) {
          result = Transform.translate(offset: Offset(dx, dy), child: result);
        }
        return result;
      },
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// MotionStagger — cascade a list of children into view.
///
/// Drop-in replacement for a [Column] (or [Row]) whose children should
/// appear one after another. Each child is wrapped in a [MotionFadeIn] with
/// an incrementing delay.
///
/// ```dart
/// MotionStagger(
///   crossAxisAlignment: CrossAxisAlignment.start,
///   children: [BalanceCard(), SizedBox(height: 24), SectionTitle()],
/// )
/// ```
/// ─────────────────────────────────────────────────────────────────────────
class MotionStagger extends StatelessWidget {
  const MotionStagger({
    super.key,
    required this.children,
    this.axis = Axis.vertical,
    this.interval = AppDuration.stagger,
    this.initialDelay = Duration.zero,
    this.duration = AppDuration.normal,
    this.slideY = 12.0,
    this.slideX = 0.0,
    this.beginScale = 1.0,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final Axis axis;

  /// Delay between consecutive children.
  final Duration interval;

  /// Delay before the first child starts.
  final Duration initialDelay;

  final Duration duration;
  final double slideY;
  final double slideX;
  final double beginScale;

  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(final BuildContext context) {
    final animated = <Widget>[
      for (var i = 0; i < children.length; i++)
        MotionFadeIn(
          delay: initialDelay + interval * i,
          duration: duration,
          slideY: slideY,
          slideX: slideX,
          beginScale: beginScale,
          child: children[i],
        ),
    ];

    return axis == Axis.vertical
        ? Column(
            mainAxisSize: mainAxisSize,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: animated,
          )
        : Row(
            mainAxisSize: mainAxisSize,
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            children: animated,
          );
  }

  /// Helper for `ListView.builder`-style call-sites: returns the per-index
  /// entrance delay so you can wrap each row yourself.
  ///
  /// ```dart
  /// itemBuilder: (ctx, i) => MotionFadeIn(
  ///   delay: MotionStagger.delayFor(i),
  ///   child: MyRow(items[i]),
  /// )
  /// ```
  static Duration delayFor(
    final int index, {
    final Duration interval = AppDuration.stagger,
    final int maxItems = 12,
  }) {
    // Cap the cascade so long lists don't make late items crawl in.
    final clamped = index < maxItems ? index : maxItems;
    return interval * clamped;
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// PressableScale — iOS-style "press to shrink" tap feedback.
///
/// Wrap any tappable surface. On press the child smoothly scales down to
/// [pressedScale] and springs back on release. Provides [onTap]/[onLongPress]
/// so it can replace a bare `GestureDetector`/`InkWell` where a ripple isn't
/// wanted.
///
/// ```dart
/// PressableScale(onTap: _open, child: MyCard())
/// ```
/// ─────────────────────────────────────────────────────────────────────────
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.duration = AppDuration.fast,
    this.curve = AppCurve.tap,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while pressed. 0.96 is a subtle, premium-feeling shrink.
  final double pressedScale;

  final Duration duration;
  final Curve curve;
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(final bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(final BuildContext context) {
    final reduce = reduceMotionOf(context);
    final scale = (_pressed && !reduce) ? widget.pressedScale : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: reduce ? Duration.zero : widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// MotionSwitcher — smooth fade (+ subtle scale) between two widgets.
///
/// Like [AnimatedSwitcher] but with Apple-flavoured defaults. Give the
/// incoming [child] a distinct `Key` so the switcher knows it changed.
///
/// ```dart
/// MotionSwitcher(child: isLoading ? Spinner(key: K('a')) : Data(key: K('b')))
/// ```
/// ─────────────────────────────────────────────────────────────────────────
class MotionSwitcher extends StatelessWidget {
  const MotionSwitcher({
    super.key,
    required this.child,
    this.duration = AppDuration.normal,
    this.beginScale = 0.98,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final double beginScale;
  final AlignmentGeometry alignment;

  @override
  Widget build(final BuildContext context) {
    final reduce = reduceMotionOf(context);
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : duration,
      switchInCurve: AppCurve.standard,
      switchOutCurve: AppCurve.standard,
      layoutBuilder: (final currentChild, final previousChildren) => Stack(
        alignment: alignment,
        children: <Widget>[
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (final child, final animation) {
        final scale = Tween<double>(begin: beginScale, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: AppCurve.standard));
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// AppMotion — shared route-level transitions and tween helpers.
/// ─────────────────────────────────────────────────────────────────────────
abstract final class AppMotion {
  /// Duration for page/route transitions.
  static const Duration pageDuration = AppDuration.page;

  /// Duration for spatial route transitions ([sharedAxisX], [riseIn]).
  static const Duration spatialDuration = AppDuration.screen;

  /// Pop duration for spatial transitions (see [AppDuration.exitFactor]).
  static final Duration spatialReverseDuration = AppDuration.exitOf(AppDuration.screen);

  /// A minimalist "fade-through": the incoming page fades in while scaling
  /// up subtly from 0.98. Matches the signature expected by
  /// `CustomTransitionPage.transitionsBuilder` and `PageRouteBuilder`.
  ///
  /// Collapses to no visual movement under reduce-motion.
  static Widget fadeThrough(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    if (reduceMotionOf(context)) return child;

    final curved = CurvedAnimation(parent: animation, curve: AppCurve.standard);
    final scale = Tween<double>(begin: 0.98, end: 1.0).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: scale, child: child),
    );
  }

  /// Parent -> child navigation ("go deeper"): the incoming page slides in
  /// from the trailing edge while the page beneath drifts back. Popping runs
  /// the reverse on the exit curve and a shorter clock.
  ///
  /// Use for destinations reached *from* the current context (a feature page
  /// opened from the quick menu). Not for peer tabs (use [fadeThrough]) or
  /// task flows (use [riseIn]). Collapses to no movement under reduce-motion.
  static Widget sharedAxisX(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    if (reduceMotionOf(context)) return child;

    final textDir = Directionality.of(context);
    final sign = textDir == TextDirection.rtl ? -1.0 : 1.0;
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppCurve.standard,
      reverseCurve: AppCurve.exit,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppCurve.standard,
      reverseCurve: AppCurve.exit,
    );
    // 0.08 of the width is ~30dp on a phone: enough to read as direction.
    final enter = Tween<Offset>(begin: Offset(0.08 * sign, 0), end: Offset.zero).animate(incoming);
    final leave = Tween<Offset>(begin: Offset.zero, end: Offset(-0.08 * sign, 0)).animate(outgoing);
    final leaveFade = Tween<double>(begin: 1, end: 0.6).animate(outgoing);

    return FadeTransition(
      opacity: leaveFade,
      child: SlideTransition(
        position: leave,
        child: FadeTransition(
          opacity: incoming,
          child: SlideTransition(position: enter, child: child),
        ),
      ),
    );
  }

  /// Task / creation flows ("start something", "see the result"): the page
  /// rises a short distance and fades in, which reads as a temporary layer
  /// above the current context rather than a place you navigated *to*.
  /// Collapses to no movement under reduce-motion.
  static Widget riseIn(
    final BuildContext context,
    final Animation<double> animation,
    final Animation<double> secondaryAnimation,
    final Widget child,
  ) {
    if (reduceMotionOf(context)) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppCurve.standard,
      reverseCurve: AppCurve.exit,
    );
    final rise = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: rise, child: child),
    );
  }

  /// Resolves an effective duration, returning [Duration.zero] when the user
  /// prefers reduced motion. Handy for ad-hoc `AnimatedFoo` widgets.
  static Duration durationFor(
    final BuildContext context, [
    final Duration duration = AppDuration.normal,
  ]) =>
      reduceMotionOf(context) ? Duration.zero : duration;
}
