import 'package:intl/intl.dart';

String formatAmount(num amount, String currencyCode) {
  final fmt = NumberFormat.simpleCurrency(name: currencyCode);
  return fmt.format(amount);
}

String formatDate(DateTime date, String pattern) {
  return DateFormat(pattern).format(date);
}