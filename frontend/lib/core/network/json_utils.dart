List<dynamic> asJsonList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['items'] is List) {
    return data['items'] as List<dynamic>;
  }
  return const [];
}

Map<String, dynamic> asJsonMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}
