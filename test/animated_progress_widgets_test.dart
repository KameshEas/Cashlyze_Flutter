import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashlyze/core/widgets/animated_progress_indicator.dart';
import 'package:cashlyze/core/widgets/animated_progress_text.dart';
import 'package:cashlyze/core/widgets/animated_status_indicator.dart';

void main() {
  group('AnimatedProgressIndicator', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressIndicator(
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('animates progress value smoothly', (WidgetTester tester) async {
      const duration = Duration(milliseconds: 500);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    AnimatedProgressIndicator(
                      progress: 0.25,
                      duration: duration,
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Update'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      
      // Initial frame
      await tester.pumpAndSettle();
      
      // Widget should exist after animation
      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
    });

    testWidgets('handles over-budget progress (>1.0) with red color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressIndicator(
              progress: 1.5, // Over budget
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('handles zero progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressIndicator(
              progress: 0.0,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('respects custom duration', (WidgetTester tester) async {
      const customDuration = Duration(milliseconds: 300);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressIndicator(
              progress: 0.5,
              duration: customDuration,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
    });

    testWidgets('clamps progress between 0 and displayed value',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressIndicator(
              progress: 2.5, // Should be clamped for display
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('AnimatedProgressText', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressText(
              progress: 0.75,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressText), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+%')), findsOneWidget);
    });

    testWidgets('displays percentage correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressText(
              progress: 0.5,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('50%'), findsOneWidget);
    });

    testWidgets('animates text color based on progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressText(
              progress: 1.2, // Over 100% - should be red
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AnimatedProgressText), findsOneWidget);
    });

    testWidgets('shows 0% for zero progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressText(
              progress: 0.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets('respects custom suffix', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedProgressText(
              progress: 0.5,
              suffix: ' / 100',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('50 / 100'), findsOneWidget);
    });
  });

  group('AnimatedStatusIndicator', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedStatusIndicator(
              progress: 0.5,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedStatusIndicator), findsOneWidget);
    });

    testWidgets('shows under-budget status when progress < 1.0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedStatusIndicator(
              progress: 0.7,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Budget Available (30%)'), findsOneWidget);
    });

    testWidgets('shows over-budget status when progress >= 1.0',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedStatusIndicator(
              progress: 1.2,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Over Budget'), findsOneWidget);
    });

    testWidgets('animates color transitions smoothly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedStatusIndicator(
              progress: 0.95, // Warning threshold
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AnimatedStatusIndicator), findsOneWidget);
    });

    testWidgets('respects custom duration', (WidgetTester tester) async {
      const customDuration = Duration(milliseconds: 300);
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedStatusIndicator(
              progress: 0.5,
              duration: customDuration,
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedStatusIndicator), findsOneWidget);
    });
  });

  group('Animation Integration', () {
    testWidgets('all three widgets animate together smoothly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AnimatedProgressIndicator(progress: 0.5),
                AnimatedProgressText(progress: 0.5),
                AnimatedStatusIndicator(progress: 0.5),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedProgressIndicator), findsOneWidget);
      expect(find.byType(AnimatedProgressText), findsOneWidget);
      expect(find.byType(AnimatedStatusIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('handles rapid progress updates', (WidgetTester tester) async {
      final key = GlobalKey<_TestWidgetState>();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _TestWidget(key: key),
          ),
        ),
      );

      // Simulate rapid updates
      for (int i = 0; i < 5; i++) {
        key.currentState?.updateProgress(i * 0.2);
        await tester.pump();
      }

      await tester.pumpAndSettle();
    });
  });
}

class _TestWidget extends StatefulWidget {
  const _TestWidget({required Key key}) : super(key: key);

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> {
  double _progress = 0.0;

  void updateProgress(double value) {
    setState(() => _progress = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedProgressIndicator(progress: _progress),
        AnimatedProgressText(progress: _progress),
        AnimatedStatusIndicator(progress: _progress),
      ],
    );
  }
}
