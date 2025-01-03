class Category {
  final int id;
  final String name;
  final int color;
  final String icon;

  Category({
    required this.id,
    required this.name,
    this.color = 0xFF2196F3,
    this.icon = 'category',
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int, // Confirma que sea un entero
      name: map['name'] as String,
      color: map['color'] is int ? map['color'] as int : int.parse(map['color']),
      icon: map['icon'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
    };
  }
}
