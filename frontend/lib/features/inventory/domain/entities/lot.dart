import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class Lot extends Equatable {
  const Lot({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    this.receivedAt,
    this.expiresOn,
  });

  final String id;
  final String productId;
  final double quantity;
  final double unitCost;
  final String? receivedAt;
  final String? expiresOn;

  factory Lot.fromJson(Map<String, dynamic> json) {
    return Lot(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
      unitCost: parseMoney(json['unit_cost']),
      receivedAt: json['received_at']?.toString(),
      expiresOn: json['expires_on']?.toString(),
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, quantity, unitCost, receivedAt, expiresOn];
}
