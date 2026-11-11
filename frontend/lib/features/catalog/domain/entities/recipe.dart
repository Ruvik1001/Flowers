import 'package:equatable/equatable.dart';
import 'package:flowers/core/network/json_utils.dart';
import 'package:flowers/features/catalog/domain/entities/recipe_item.dart';

class Recipe extends Equatable {
  const Recipe({
    required this.id,
    required this.bouquetId,
    required this.items,
    required this.archived,
  });

  final String id;
  final String bouquetId;
  final List<RecipeItem> items;
  final bool archived;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return Recipe(
      id: json['id']?.toString() ?? '',
      bouquetId: json['bouquet_id']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .map((e) => RecipeItem.fromJson(asJsonMap(e)))
              .toList()
          : const [],
      archived: json['archived'] == true,
    );
  }

  @override
  List<Object?> get props => [id, bouquetId, items, archived];
}
