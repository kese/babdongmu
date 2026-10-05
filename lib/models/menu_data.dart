/// 가게 메뉴 데이터 모델
library;

class MenuItem {
  final String id;
  final String name;
  final int price;
  final String? description;
  final String? imageUrl;
  final String? category;

  const MenuItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: _coerceString(json['id'] ?? json['menuId'] ?? json['menu_id']),
      name: _coerceString(json['name'] ?? json['menuName'] ?? json['menu_name']),
      price: _coerceInt(json['price']),
      description: _coerceOptionalString([
        json['description'],
        json['desc'],
        json['detail'],
      ]),
      imageUrl: _coerceOptionalString([
        json['imageUrl'],
        json['image_url'],
        json['image'],
        json['img'],
      ]),
      category: _coerceOptionalString([
        json['category'],
        json['categoryName'],
        json['category_name'],
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (category != null) 'category': category,
    };
  }
}

String _coerceString(dynamic value) {
  if (value == null) return '';
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') {
    return '';
  }
  return raw;
}

String? _coerceOptionalString(List<dynamic> candidates) {
  for (final candidate in candidates) {
    if (candidate == null) continue;
    final value = _coerceString(candidate);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int _coerceInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value.trim().replaceAll(',', '')) ?? 0;
  }
  return 0;
}

