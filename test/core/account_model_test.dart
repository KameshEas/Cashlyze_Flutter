// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:cashlyze/core/models/account.dart';
import 'package:cashlyze/core/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountKind.fromTypeName', () {
    test('maps the server type names', () {
      expect(AccountKind.fromTypeName('Credit Card'), AccountKind.creditCard);
      expect(AccountKind.fromTypeName('Debit Card'), AccountKind.debitCard);
      expect(AccountKind.fromTypeName('UPI'), AccountKind.upi);
      expect(AccountKind.fromTypeName('Cash'), AccountKind.cash);
    });

    test('anything else (Checking, Savings, Wallet, future types) is a bank-style account', () {
      for (final n in ['Checking', 'Savings', 'Wallet', 'Investment', 'Loan', 'Something New', '', null]) {
        expect(AccountKind.fromTypeName(n), AccountKind.bank, reason: '$n');
      }
    });

    test('only credit and debit cards ask for last 4 digits', () {
      expect(AccountKind.creditCard.isCard, isTrue);
      expect(AccountKind.debitCard.isCard, isTrue);
      expect(AccountKind.upi.isCard, isFalse);
      expect(AccountKind.cash.isCard, isFalse);
    });
  });

  group('AccountModel', () {
    Map<String, dynamic> json({final Map<String, dynamic> extra = const {}}) => {
          'id': 'a1',
          'name': 'HDFC Regalia',
          'account_type_id': 'at_3',
          'account_type': {'id': 'at_3', 'name': 'Credit Card'},
          'currency_code': 'INR',
          ...extra,
        };

    test('parses the API payload', () {
      final a = AccountModel.fromJson(json(extra: {'institution': 'HDFC', 'last4': '4821'}));
      expect(a.kind, AccountKind.creditCard);
      expect((a.institution, a.last4, a.upiId), ('HDFC', '4821', null));
    });

    test('blank detail fields from the server count as unset', () {
      final a = AccountModel.fromJson(json(extra: {'institution': '  ', 'last4': '', 'upi_id': null}));
      expect((a.institution, a.last4, a.upiId), (null, null, null));
    });

    test('labels: short label shows card digits; subtitle joins bank and digits / UPI id', () {
      final card = AccountModel.fromJson(json(extra: {'institution': 'HDFC', 'last4': '4821'}));
      expect(card.shortLabel, 'HDFC Regalia •• 4821');
      expect(card.subtitle, 'HDFC · •• 4821');

      final upi = AccountModel.fromJson({
        'id': 'a2',
        'name': 'PhonePe',
        'account_type': {'id': 'at_8', 'name': 'UPI'},
        'institution': 'PhonePe',
        'upi_id': 'me@okhdfc',
      });
      expect(upi.shortLabel, 'PhonePe');
      expect(upi.subtitle, 'PhonePe · me@okhdfc');

      final cash = AccountModel.fromJson({
        'id': 'a3',
        'name': 'Wallet',
        'account_type': {'id': 'at_9', 'name': 'Cash'},
      });
      expect(cash.subtitle, isNull);
    });
  });

  group('AccountSpend', () {
    test('parses the spend-summary row', () {
      final s = AccountSpend.fromJson({'account_id': 'a1', 'spend': 750, 'income': 100.5, 'txn_count': 3});
      expect((s.accountId, s.spend, s.income, s.txnCount), ('a1', 750.0, 100.5, 3));
    });
  });

  group('TransactionModel.accountId', () {
    final base = TransactionModel(id: 't', userId: 'u', title: 'x', amount: -1, date: DateTime(2026), accountId: 'a1');

    test('round-trips and takes part in equality', () {
      expect(TransactionModel.fromRTDB('t', base.toRTDB()).accountId, 'a1');
      expect(base == base.copyWith(accountId: 'a2'), isFalse);
      expect(base == base.copyWith(), isTrue);
    });

    test('copyWith can clear it', () {
      expect(base.copyWith(clearAccountId: true).accountId, isNull);
    });
  });
}
