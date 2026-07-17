import 'package:intl/intl.dart';

String formatAmount(final num amount, final String currencyCode) {
  final fmt = NumberFormat.simpleCurrency(name: currencyCode);
  return fmt.format(amount);
}

/// The bare currency symbol (e.g. '₹', '\$') for a given currency code,
/// for use as a text-field prefix where a fully formatted amount isn't wanted.
String currencySymbol(final String currencyCode) {
  return NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
}

String formatDate(final DateTime date, final String pattern) {
  return DateFormat(pattern).format(date);
}

/// Generates a human-readable balance status message
/// 
/// Returns object with:
/// - 'message': Clear status text (e.g., "₹2,400 left" or "Overspent by ₹630")
/// - 'isPositive': true if balance >= 0, false if overspent
class BalanceStatus {
  
  const BalanceStatus({
    required this.message,
    required this.isPositive,
  });
  final String message;
  final bool isPositive;
}

BalanceStatus getBalanceStatus(final num balance, final String currencyCode) {
  final absBalance = balance.abs();
  final fmt = NumberFormat.simpleCurrency(name: currencyCode);
  final formattedAmount = fmt.format(absBalance);
  
  if (balance >= 0) {
    return BalanceStatus(
      message: '$formattedAmount left',
      isPositive: true,
    );
  } else {
    return BalanceStatus(
      message: 'Overspent by $formattedAmount',
      isPositive: false,
    );
  }
}
