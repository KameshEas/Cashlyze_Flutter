import 'package:intl/intl.dart';

String formatAmount(num amount, String currencyCode) {
  final fmt = NumberFormat.simpleCurrency(name: currencyCode);
  return fmt.format(amount);
}

String formatDate(DateTime date, String pattern) {
  return DateFormat(pattern).format(date);
}

/// Generates a human-readable balance status message
/// 
/// Returns object with:
/// - 'message': Clear status text (e.g., "₹2,400 left" or "Overspent by ₹630")
/// - 'isPositive': true if balance >= 0, false if overspent
class BalanceStatus {
  final String message;
  final bool isPositive;
  
  const BalanceStatus({
    required this.message,
    required this.isPositive,
  });
}

BalanceStatus getBalanceStatus(num balance, String currencyCode) {
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