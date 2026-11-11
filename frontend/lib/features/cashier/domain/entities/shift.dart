import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/money.dart';

class Shift extends Equatable {
  const Shift({
    required this.id,
    required this.cashierId,
    required this.openingCash,
    this.openedAt,
    this.closedAt,
    this.cashSales = 0,
    this.cashRefunds = 0,
    this.expectedCash,
    this.actualCash,
    this.discrepancy,
  });

  final String id;
  final String cashierId;
  final double openingCash;
  final String? openedAt;
  final String? closedAt;
  final double cashSales;
  final double cashRefunds;
  final double? expectedCash;
  final double? actualCash;
  final double? discrepancy;

  bool get isOpen => closedAt == null;

  factory Shift.fromJson(Map<String, dynamic> json) {
    final opening = parseMoney(json['opening_cash']);
    final sales = parseMoney(json['cash_sales']);
    final refunds = parseMoney(json['cash_refunds']);
    final expected = json.containsKey('expected_cash')
        ? parseMoney(json['expected_cash'])
        : opening + sales - refunds;
    final actual =
        json['actual_cash'] == null ? null : parseMoney(json['actual_cash']);
    final discrepancy = json.containsKey('discrepancy')
        ? (json['discrepancy'] == null
            ? null
            : parseMoney(json['discrepancy']))
        : (actual == null ? null : actual - expected);

    return Shift(
      id: json['id']?.toString() ?? '',
      cashierId: json['cashier_id']?.toString() ?? '',
      openingCash: opening,
      openedAt: json['opened_at']?.toString(),
      closedAt: json['closed_at']?.toString(),
      cashSales: sales,
      cashRefunds: refunds,
      expectedCash: expected,
      actualCash: actual,
      discrepancy: discrepancy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cashierId,
        openingCash,
        openedAt,
        closedAt,
        cashSales,
        cashRefunds,
        expectedCash,
        actualCash,
        discrepancy,
      ];
}
