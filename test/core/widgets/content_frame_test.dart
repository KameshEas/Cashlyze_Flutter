import 'package:cashlyze/core/widgets/content_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<double> _contentWidth(final WidgetTester tester, final double windowWidth) async {
  tester.view
    ..physicalSize = Size(windowWidth, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: ContentFrame(child: SizedBox.expand(key: ValueKey('content'))))),
  );
  return tester.getSize(find.byKey(const ValueKey('content'))).width;
}

void main() {
  testWidgets('phones are untouched', (final tester) async {
    expect(await _contentWidth(tester, 390), 390);
  });

  testWidgets('a window exactly at the cap is untouched', (final tester) async {
    expect(await _contentWidth(tester, ContentFrame.defaultMaxWidth), ContentFrame.defaultMaxWidth);
  });

  testWidgets('tablets get a capped, centred column', (final tester) async {
    expect(await _contentWidth(tester, 1000), ContentFrame.defaultMaxWidth);
    final left = tester.getTopLeft(find.byKey(const ValueKey('content'))).dx;
    expect(left, (1000 - ContentFrame.defaultMaxWidth) / 2);
  });
}
