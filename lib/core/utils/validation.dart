bool validateTitle(String title) => title.trim().isNotEmpty;

bool validateAmount(String amountText) {
  final v = double.tryParse(amountText);
  return v != null && !v.isNaN;
}

bool validateDate(DateTime date) => !date.isAfter(DateTime.now().add(const Duration(days: 1)));