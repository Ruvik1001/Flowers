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
    this.folderId,
    this.sortOrder = 0,
  });

  final String id;
  final String productId;
  final double quantity;
  final double unitCost;
  final String? receivedAt;
  final String? expiresOn;
  final String? folderId;
  final int sortOrder;

  factory Lot.fromJson(Map<String, dynamic> json) {
    return Lot(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: parseMoney(json['quantity']),
      unitCost: parseMoney(json['unit_cost']),
      receivedAt: json['received_at']?.toString(),
      expiresOn: json['expires_on']?.toString(),
      folderId: json['folder_id']?.toString(),
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, quantity, unitCost, receivedAt, expiresOn, folderId, sortOrder];
}
