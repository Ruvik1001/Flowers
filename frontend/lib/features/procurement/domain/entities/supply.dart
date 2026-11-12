import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/procurement/domain/entities/supply_line.dart';

class Supply extends Equatable {
  const Supply({
    required this.id,
    required this.supplierId,
    required this.lines,
    this.createdAt,
  });

  final String id;
  final String supplierId;
  final List<SupplyLine> lines;
  final String? createdAt;

  factory Supply.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'];
    return Supply(
      id: json['id']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
      lines: raw is List
          ? raw.map((e) => SupplyLine.fromJson(asJsonMap(e))).toList()
          : const [],
    );
  }

  @override
  List<Object?> get props => [id, supplierId, lines, createdAt];
}
