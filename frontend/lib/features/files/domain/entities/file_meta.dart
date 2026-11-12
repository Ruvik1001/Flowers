import 'package:equatable/equatable.dart';

class FileMeta extends Equatable {
  const FileMeta({
    required this.id,
    required this.originalName,
    required this.contentType,
    required this.size,
  });

  final String id;
  final String originalName;
  final String contentType;
  final int size;

  factory FileMeta.fromJson(Map<String, dynamic> json) {
    return FileMeta(
      id: json['id']?.toString() ?? '',
      originalName: json['original_name']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      size: json['size'] is num
          ? (json['size'] as num).toInt()
          : int.tryParse(json['size']?.toString() ?? '') ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, originalName, contentType, size];
}
