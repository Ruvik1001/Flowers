/// Normalizes inconsistent backend money/quantity encodings.
double parseMoney(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  if (value is Map) {
    final amount = value['amount'];
    if (amount is num) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0;
  }
  return 0;
}

String moneyToApi(num value) => value.toStringAsFixed(2);

String formatRub(num value) => '${value.toStringAsFixed(2)} ₽';
