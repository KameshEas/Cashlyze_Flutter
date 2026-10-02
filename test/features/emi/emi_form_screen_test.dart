import 'package:cashlyze/core/models/emi.dart';
import 'package:cashlyze/core/providers/shared_prefs_provider.dart';
import 'package:cashlyze/features/emi/emi_form_screen.dart';
import 'package:cashlyze/features/emi/widgets/emi_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(final WidgetTester tester, {final bool reduce = false, final EMIPlan? plan}) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        builder: (final context, final child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: child!,
        ),
        home: EMIFormScreen(initialPlan: plan),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _amount => find.byType(TextField).at(0);
Finder get _rate => find.byType(TextField).at(1);
Finder get _tenure => find.byType(TextField).at(2);

Future<void> _fill(final WidgetTester tester) async {
  await tester.enterText(_amount, '100000');
  await tester.enterText(_rate, '12');
  await tester.enterText(_tenure, '12');
  await tester.pumpAndSettle();
}

void main() {
  _formatterTests();

  testWidgets('starts clean: no preview, interest rate visible', (final tester) async {
    await _pump(tester);
    expect(find.byType(EmiPreviewCard), findsNothing);
    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('Create plan'), findsOneWidget);
  });

  testWidgets('preview appears once amount, rate and tenure are usable', (final tester) async {
    await _pump(tester);
    await tester.enterText(_amount, '100000');
    await tester.enterText(_tenure, '12');
    await tester.pumpAndSettle();
    expect(find.byType(EmiPreviewCard), findsNothing, reason: 'rate still missing');

    await tester.enterText(_rate, '12');
    await tester.pumpAndSettle();
    expect(find.byType(EmiPreviewCard), findsOneWidget);
    // 100,000 at 12% p.a. over 12 months: 8,884.88 a month.
    expect(find.textContaining('8,884.88'), findsWidgets);
    // Shown twice by design: the detail card and the pinned summary line.
    expect(find.text('/ month'), findsNWidgets(2));
    expect(find.byType(EmiSummaryLine), findsOneWidget);
  });

  testWidgets('preview disappears again when a value becomes invalid', (final tester) async {
    await _pump(tester);
    await _fill(tester);
    expect(find.byType(EmiPreviewCard), findsOneWidget);
    await tester.enterText(_tenure, '');
    await tester.pumpAndSettle();
    expect(find.byType(EmiPreviewCard), findsNothing);
  });

  testWidgets('zero-cost collapses the rate row and previews with no interest', (final tester) async {
    await _pump(tester);
    await tester.enterText(_amount, '100000');
    await tester.enterText(_tenure, '12');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Interest rate'), findsNothing);
    expect(find.byType(EmiPreviewCard), findsOneWidget);
    expect(find.textContaining('8,333.33'), findsWidgets);
    expect(find.text('None'), findsOneWidget, reason: 'total interest reads None');
  });

  testWidgets('switching zero-cost off restores the previous rate', (final tester) async {
    await _pump(tester);
    await tester.enterText(_rate, '9.5');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_rate).controller!.text, '9.5');
  });

  testWidgets('submitting an empty form shows every error inline and focuses the amount', (final tester) async {
    await _pump(tester);
    await tester.tap(find.text('Create plan'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Enter a valid rate'), findsOneWidget);
    expect(find.text('Enter the tenure in months'), findsOneWidget);
    expect(tester.widget<TextField>(_amount).focusNode!.hasFocus, isTrue);
  });

  testWidgets('an error clears as soon as the field is edited', (final tester) async {
    await _pump(tester);
    await tester.tap(find.text('Create plan'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount'), findsOneWidget);

    await tester.enterText(_amount, '5');
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid amount'), findsNothing);
    expect(find.text('Enter a valid rate'), findsOneWidget, reason: 'other fields keep their errors');
  });

  testWidgets('zero-cost does not require a rate on submit', (final tester) async {
    await _pump(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create plan'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid rate'), findsNothing);
    expect(find.text('Enter a valid amount'), findsOneWidget);
  });

  testWidgets('frequency selector changes the schedule and the preview period', (final tester) async {
    await _pump(tester);
    await _fill(tester);
    expect(find.text('/ month'), findsNWidgets(2));

    await tester.tap(find.text('Quarterly'));
    await tester.pumpAndSettle();
    expect(find.text('/ quarter'), findsNWidgets(2));

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(find.text('/ week'), findsNWidgets(2));
  });

  testWidgets('editing a plan prefills the fields and shows its preview', (final tester) async {
    await _pump(
      tester,
      plan: EMIPlan(
        id: 'p1',
        userId: 'u',
        loanAmount: 100000,
        annualInterestRate: 12,
        tenureMonths: 12,
        startDate: DateTime(2026),
        frequency: PaymentFrequency.monthly,
        active: true,
      ),
    );
    expect(find.text('Edit EMI Plan'), findsOneWidget);
    expect(find.text('Update plan'), findsOneWidget);
    expect(find.byType(EmiPreviewCard), findsOneWidget);
    expect(find.textContaining('8,884.88'), findsWidgets);
  });

  testWidgets('the summary line hides with the preview', (final tester) async {
    await _pump(tester);
    expect(find.byType(EmiSummaryLine), findsNothing);
    await _fill(tester);
    expect(find.byType(EmiSummaryLine), findsOneWidget);
    await tester.enterText(_rate, '');
    await tester.pumpAndSettle();
    expect(find.byType(EmiSummaryLine), findsNothing);
  });

  testWidgets('the amount is grouped as it is typed (lakh grouping for INR)', (final tester) async {
    await _pump(tester);
    await tester.enterText(_amount, '250000');
    await tester.pump();
    expect(tester.widget<TextField>(_amount).controller!.text, '2,50,000');

    await tester.enterText(_amount, '1234567.5');
    await tester.pump();
    expect(tester.widget<TextField>(_amount).controller!.text, '12,34,567.5');
  });

  testWidgets('grouped amounts still compute correctly', (final tester) async {
    await _pump(tester);
    await _fill(tester);
    expect(tester.widget<TextField>(_amount).controller!.text, '1,00,000');
    expect(find.textContaining('8,884.88'), findsWidgets);
  });

  testWidgets('the amount field rejects letters and a third decimal', (final tester) async {
    await _pump(tester);
    await tester.enterText(_amount, '12.345');
    await tester.pump();
    expect(tester.widget<TextField>(_amount).controller!.text, isNot(contains('345')));
    await tester.enterText(_amount, 'abc');
    await tester.pump();
    expect(tester.widget<TextField>(_amount).controller!.text, isNot(contains('a')));
  });

  testWidgets('an absurd tenure hides the preview instead of computing it', (final tester) async {
    await _pump(tester);
    await tester.enterText(_amount, '100000');
    await tester.enterText(_rate, '12');
    await tester.enterText(_tenure, '99999');
    await tester.pumpAndSettle();
    expect(find.byType(EmiPreviewCard), findsNothing);
  });

  testWidgets('works under reduced motion (no animation assertions)', (final tester) async {
    await _pump(tester, reduce: true);
    await _fill(tester);
    expect(find.byType(EmiPreviewCard), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(find.text('Interest rate'), findsNothing);
    await tester.tap(find.text('Create plan'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

void _formatterTests() {
  group('AmountGroupingFormatter', () {
    const f = AmountGroupingFormatter();
    TextEditingValue run(final String old, final String next, {final int? caret}) => f.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: next, selection: TextSelection.collapsed(offset: caret ?? next.length)),
        );

    test('groups lakh style and keeps the caret at the end', () {
      final v = run('', '250000');
      expect(v.text, '2,50,000');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('western grouping for other currencies', () {
      const us = AmountGroupingFormatter(locale: 'en_US');
      final v = us.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '250000', selection: TextSelection.collapsed(offset: 6)),
      );
      expect(v.text, '250,000');
    });

    test('keeps the caret after the same digit when editing in the middle', () {
      // "2,50,000" with a digit typed after "2,5": raw 2.5|0000 -> caret after 3rd digit.
      final v = run('2,50,000', '2,591,000', caret: 4);
      expect(v.text, '25,91,000');
      expect(v.text.substring(0, v.selection.baseOffset).replaceAll(',', ''), '259');
    });

    test('rejects a third decimal and non-numeric input by keeping the old value', () {
      final old = run('', '12.5');
      expect(f.formatEditUpdate(old, const TextEditingValue(text: '12.555')).text, old.text);
      expect(f.formatEditUpdate(old, const TextEditingValue(text: '12.5x')).text, old.text);
    });

    test('a leading dot becomes 0.', () {
      expect(run('', '.5').text, '0.5');
    });

    test('strips leading zeros but keeps a single zero', () {
      expect(run('', '007').text, '7');
      expect(run('', '0').text, '0');
    });

    test('caps the integer length', () {
      final old = run('', '123456789012');
      expect(f.formatEditUpdate(old, const TextEditingValue(text: '1234567890123')).text, old.text);
    });

    test('format() shows decimals only when needed, and parse() round-trips', () {
      expect(AmountGroupingFormatter.format(250000), '2,50,000');
      expect(AmountGroupingFormatter.format(250000.5), '2,50,000.5');
      expect(AmountGroupingFormatter.format(1234.56, locale: 'en_US'), '1,234.56');
      expect(AmountGroupingFormatter.parse('2,50,000.5'), 250000.5);
      expect(AmountGroupingFormatter.parse(''), isNull);
    });
  });
}
