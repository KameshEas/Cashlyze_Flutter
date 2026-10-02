import 'package:cashlyze/core/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Builder = Widget Function(BuildContext, Animation<double>, Animation<double>, Widget);

Future<Offset> _slideAt(
  final WidgetTester tester,
  final _Builder builder, {
  required final double value,
  final bool reduce = false,
  final TextDirection dir = TextDirection.ltr,
}) async {
  final anim = AlwaysStoppedAnimation<double>(value);
  const secondary = AlwaysStoppedAnimation<double>(0);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: dir,
        child: Builder(
          builder: (final context) => builder(context, anim, secondary, const SizedBox(key: ValueKey('page'))),
        ),
      ),
    ),
  );
  final slides = tester.widgetList<SlideTransition>(find.byType(SlideTransition));
  return slides.isEmpty ? Offset.zero : slides.last.position.value;
}

void main() {
  group('AppDuration tiers', () {
    test('sit inside the documented ranges', () {
      expect(AppDuration.micro.inMilliseconds, inInclusiveRange(100, 200));
      expect(AppDuration.component.inMilliseconds, inInclusiveRange(180, 350));
      expect(AppDuration.screen.inMilliseconds, inInclusiveRange(250, 500));
    });

    test('exits are shorter than their enters', () {
      expect(AppDuration.exitOf(AppDuration.screen), lessThan(AppDuration.screen));
      expect(AppMotion.spatialReverseDuration, lessThan(AppMotion.spatialDuration));
    });
  });

  group('sharedAxisX', () {
    testWidgets('enters from the trailing edge and settles at rest', (final tester) async {
      final start = await _slideAt(tester, AppMotion.sharedAxisX, value: 0);
      expect(start.dx, greaterThan(0));
      final end = await _slideAt(tester, AppMotion.sharedAxisX, value: 1);
      expect(end, Offset.zero);
    });

    testWidgets('mirrors in RTL', (final tester) async {
      final start = await _slideAt(tester, AppMotion.sharedAxisX, value: 0, dir: TextDirection.rtl);
      expect(start.dx, lessThan(0));
    });

    testWidgets('does not move under reduced motion', (final tester) async {
      final start = await _slideAt(tester, AppMotion.sharedAxisX, value: 0, reduce: true);
      expect(start, Offset.zero);
      expect(find.byKey(const ValueKey('page')), findsOneWidget);
    });
  });

  group('riseIn', () {
    testWidgets('rises from below and settles at rest', (final tester) async {
      final start = await _slideAt(tester, AppMotion.riseIn, value: 0);
      expect(start.dy, greaterThan(0));
      expect(start.dx, 0);
      final end = await _slideAt(tester, AppMotion.riseIn, value: 1);
      expect(end, Offset.zero);
    });

    testWidgets('does not move under reduced motion', (final tester) async {
      final start = await _slideAt(tester, AppMotion.riseIn, value: 0, reduce: true);
      expect(start, Offset.zero);
    });
  });
}
