import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class SaleLine extends Equatable {
  const SaleLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final double quantity;
  final double unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) {
    return SaleLine(
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
      unitPrice: parseMoney(json['unit_price']),
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': moneyToApi(quantity),
        'unit_price': moneyToApi(unitPrice),
      };

  @override
  List<Object?> get props => [productId, quantity, unitPrice];
}
