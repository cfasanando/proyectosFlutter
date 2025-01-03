class Note {
  final int? id;
  final String title;
  final String content;
  final int? categoryId;
  final bool isFavorite;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.categoryId,
    this.isFavorite = false, // Valor predeterminado
  });

  // Convierte un objeto Note a un Map para guardar en la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'isFavorite': isFavorite ? 1 : 0, // Convertir a entero para SQLite
    };
  }

  // Crea un objeto Note desde un Map (consulta de la base de datos)
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      categoryId: map['categoryId'] != null
          ? (map['categoryId'] is int
              ? map['categoryId'] as int
              : int.tryParse(map['categoryId'].toString()))
          : null,
      isFavorite: map['isFavorite'] == 1,
    );
  }
}
