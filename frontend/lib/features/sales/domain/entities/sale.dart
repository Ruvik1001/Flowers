import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/core/network/money.dart';
import 'package:flowers/features/sales/domain/entities/payment.dart';
import 'package:flowers/features/sales/domain/entities/sale_line.dart';

class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.total,
    required this.lines,
    required this.payments,
  });

  final String id;
  final double total;
  final List<SaleLine> lines;
  final List<Payment> payments;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id']?.toString() ?? '',
      total: parseMoney(json['total']),
      lines: (json['lines'] as List?)
              ?.map((e) => SaleLine.fromJson(asJsonMap(e)))
              .toList() ??
          const [],
      payments: (json['payments'] as List?)
              ?.map((e) => Payment.fromJson(asJsonMap(e)))
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [id, total, lines, payments];
}
