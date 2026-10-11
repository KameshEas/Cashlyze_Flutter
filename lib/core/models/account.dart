import 'package:flutter/material.dart';

/// The kinds of payment instrument the app treats specially. Derived from the
/// server's account-type *name* (types are seed data on the backend), so a
/// future type still works: it just falls back to [bank].
enum AccountKind {
  creditCard,
  debitCard,
  upi,
  cash,
  bank;

  static AccountKind fromTypeName(final String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('credit')) return AccountKind.creditCard;
    if (n.contains('debit')) return AccountKind.debitCard;
    if (n.contains('upi')) return AccountKind.upi;
    if (n.contains('cash')) return AccountKind.cash;
    return AccountKind.bank;
  }

  bool get isCard => this == creditCard || this == debitCard;

  IconData get icon => switch (this) {
        creditCard => Icons.credit_card_rounded,
        debitCard => Icons.payment_rounded,
        upi => Icons.qr_code_2_rounded,
        cash => Icons.payments_outlined,
        bank => Icons.account_balance_rounded,
      };
}

@immutable
class AccountType {
  const AccountType({required this.id, required this.name});

  factory AccountType.fromJson(final Map<String, dynamic> json) =>
      AccountType(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;

  AccountKind get kind => AccountKind.fromTypeName(name);

  @override
  bool operator ==(final Object other) =>
      other is AccountType && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// A payment account / instrument a transaction can be tagged with.
@immutable
class AccountModel {
  const AccountModel({
    required this.id,
    required this.name,
    required this.typeId,
    required this.typeName,
    this.institution,
    this.last4,
    this.upiId,
    this.currencyCode = 'INR',
  });

  factory AccountModel.fromJson(final Map<String, dynamic> json) {
    final type = json['account_type'] as Map<String, dynamic>?;
    return AccountModel(
      id: json['id'] as String,
      name: json['name'] as String,
      typeId: json['account_type_id'] as String? ?? type?['id'] as String? ?? '',
      typeName: type?['name'] as String? ?? '',
      institution: _blankToNull(json['institution'] as String?),
      last4: _blankToNull(json['last4'] as String?),
      upiId: _blankToNull(json['upi_id'] as String?),
      currencyCode: json['currency_code'] as String? ?? 'INR',
    );
  }

  final String id;
  final String name;
  final String typeId;
  final String typeName;
  final String? institution;
  final String? last4;
  final String? upiId;
  final String currencyCode;

  AccountKind get kind => AccountKind.fromTypeName(typeName);

  /// "Name •• 4821" for cards, "Name" otherwise: the compact label used in
  /// pickers and next to a transaction.
  String get shortLabel => last4 == null ? name : '$name •• $last4';

  /// Secondary line: bank/issuer and the card digits or UPI id.
  String? get subtitle {
    final parts = <String>[
      if (institution != null) institution!,
      if (kind.isCard && last4 != null) '•• $last4',
      if (kind == AccountKind.upi && upiId != null) upiId!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? _blankToNull(final String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  @override
  bool operator ==(final Object other) =>
      identical(this, other) ||
      other is AccountModel &&
          other.id == id &&
          other.name == name &&
          other.typeId == typeId &&
          other.typeName == typeName &&
          other.institution == institution &&
          other.last4 == last4 &&
          other.upiId == upiId &&
          other.currencyCode == currencyCode;

  @override
  int get hashCode =>
      Object.hash(id, name, typeId, typeName, institution, last4, upiId, currencyCode);
}

/// One account's totals for a period (from `GET /accounts/spend-summary`).
@immutable
class AccountSpend {
  const AccountSpend({
    required this.accountId,
    required this.spend,
    required this.income,
    required this.txnCount,
  });

  factory AccountSpend.fromJson(final Map<String, dynamic> json) => AccountSpend(
        accountId: json['account_id'] as String,
        spend: (json['spend'] as num).toDouble(),
        income: (json['income'] as num).toDouble(),
        txnCount: (json['txn_count'] as num).toInt(),
      );

  final String accountId;
  final double spend;
  final double income;
  final int txnCount;
}
