class CategoryModel {
  final String id;
  final String userId;
  final String name;
  final String? icon;
  final int? color;

  const CategoryModel({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    this.color,
  });

  factory CategoryModel.fromRTDB(String id, Map<String, dynamic> data) {
    return CategoryModel(
      id: id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      icon: data['icon'] as String?,
      color: data['color'] as int?,
    );
  }

  Map<String, dynamic> toRTDB() {
    return {
      'userId': userId,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }
}