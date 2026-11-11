import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class InventoryCount extends Equatable {
  const InventoryCount({
    required this.id,
    required this.productId,
    required this.expected,
    required this.actual,
    required this.discrepancy,
  });

  final String id;
  final String productId;
  final double expected;
  final double actual;
  final double discrepancy;

  factory InventoryCount.fromJson(Map<String, dynamic> json) {
    final expected = parseMoney(json['expected']);
    final actual = parseMoney(json['actual']);
    final discrepancy = json.containsKey('discrepancy')
        ? parseMoney(json['discrepancy'])
        : actual - expected;
    return InventoryCount(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      expected: expected,
      actual: actual,
      discrepancy: discrepancy,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, expected, actual, discrepancy];
}
