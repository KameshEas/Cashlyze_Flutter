bool validateTitle(final String title) => title.trim().isNotEmpty;

bool validateAmount(final String amountText) {
  final v = double.tryParse(amountText);
  return v != null && !v.isNaN;
}

bool validateDate(final DateTime date) => !date.isAfter(DateTime.now().add(const Duration(days: 1)));
