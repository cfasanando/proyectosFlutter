import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DBHelper {
  static const _dbName = 'notes.db';
  static const _dbVersion = 2;
  static const _tableName = 'notes';

  static final DBHelper instance = DBHelper._privateConstructor();
  static Database? _database;

  DBHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Configura sqflite_common_ffi para entornos de escritorio
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, _dbName);
    print('Database path: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Crear tabla de categorías
    await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      color INTEGER DEFAULT 0xFF2196F3,
      icon TEXT DEFAULT 'category'
    )
  ''');

    // Crear tabla de notas
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        categoryId INTEGER,
        isFavorite INTEGER DEFAULT 0,
        reminderDate TEXT,
        reminderTime TEXT,        
        FOREIGN KEY (categoryId) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // Crear tabla de etiquetas
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Crear tabla de relación nota-etiqueta
    await db.execute('''
      CREATE TABLE note_tags (
        noteId INTEGER,
        tagId INTEGER,
        PRIMARY KEY (noteId, tagId),
        FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (tagId) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // Crear tabla de adjuntos
    await db.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER NOT NULL,
        filePath TEXT NOT NULL,
        FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');
  } 

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Crear tabla de adjuntos si no existe
      await db.execute('''
        CREATE TABLE attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          noteId INTEGER NOT NULL,
          filePath TEXT NOT NULL,
          FOREIGN KEY (noteId) REFERENCES notes (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // Insertar un adjunto
  Future<int> insertAttachment(int noteId, String filePath) async {
    final db = await instance.database;
    return await db.insert('attachments', {
      'noteId': noteId,
      'filePath': filePath,
    });
  }

  // Consultar todos los adjuntos de una nota
  Future<List<Map<String, dynamic>>> queryAttachments(int noteId) async {
    final db = await instance.database;
    return await db.query(
      'attachments',
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }

  // Eliminar un adjunto
  Future<int> deleteAttachment(int id) async {
    final db = await instance.database;
    return await db.delete(
      'attachments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Eliminar todos los adjuntos de una nota
  Future<int> deleteAttachmentsForNote(int noteId) async {
    final db = await instance.database;
    return await db.delete(
      'attachments',
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }

  Future<Map<String, dynamic>?> queryNoteWithAttachments(int noteId) async {
    final db = await instance.database;

    final noteResult = await db.rawQuery('''
      SELECT n.*, c.name as categoryName, c.color as categoryColor, c.icon as categoryIcon
      FROM notes n
      LEFT JOIN categories c ON n.categoryId = c.id
      WHERE n.id = ?
    ''', [noteId]);

    if (noteResult.isEmpty) return null;

    final attachmentsResult = await queryAttachments(noteId);
    final tagsResult = await queryTagsForNote(noteId);

    return {
      ...noteResult.first,
      'attachments': attachmentsResult,
      'tags': tagsResult,
    };
  }

  // Métodos para etiquetas
  Future<int> insertTag(String name) async {
    final db = await instance.database;
    return await db.insert('tags', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> queryAllTags() async {
    final db = await instance.database;
    return await db.query('tags');
  }

  Future<int> deleteTag(int id) async {
    final db = await instance.database;
    return await db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  // Relacionar notas con etiquetas
  Future<void> attachTagToNote(int noteId, int tagId) async {
    final db = await instance.database;
    await db.insert('note_tags', {'noteId': noteId, 'tagId': tagId}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> detachTagFromNote(int noteId, int tagId) async {
    final db = await instance.database;
    await db.delete('note_tags', where: 'noteId = ? AND tagId = ?', whereArgs: [noteId, tagId]);
  }

  Future<List<Map<String, dynamic>>> queryTagsForNote(int noteId) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT tags.* FROM tags
      INNER JOIN note_tags ON tags.id = note_tags.tagId
      WHERE note_tags.noteId = ?
    ''', [noteId]);
    return result; // Asegúrate de que esto devuelve el tipo esperado
  }

  Future<List<Map<String, dynamic>>> queryNotesByTag(int tagId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT notes.* FROM notes
      INNER JOIN note_tags ON notes.id = note_tags.noteId
      WHERE note_tags.tagId = ?
    ''', [tagId]);
  }

  Future<int> toggleFavorite(int id, bool isFavorite) async {
    final db = await instance.database;
    return await db.update(
      'notes',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> queryNoteById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> queryNoteByIdWithTags(int noteId) async {
    final db = await instance.database;

    // Consulta de la nota
    final noteResult = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );

    if (noteResult.isEmpty) return null;

    // Consulta de etiquetas
    final tagsResult = await queryTagsForNote(noteId);

    return {
      ...noteResult.first,
      'tags': tagsResult, // Mantén tags como List<Map<String, dynamic>>
    };
  }

  Future<List<Map<String, dynamic>>> queryNotesWithAdvancedFilters({
    String? searchText,
    int? categoryId,
    int? tagId,
    bool onlyFavorites = false,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await instance.database;

    // Crear cláusulas WHERE dinámicas
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    // Filtro por texto de búsqueda
    if (searchText != null && searchText.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR content LIKE ?)');
      whereArgs.add('%$searchText%');
      whereArgs.add('%$searchText%');
    }

    // Filtro por categoría
    if (categoryId != null) {
      whereClauses.add('categoryId = ?');
      whereArgs.add(categoryId);
    }

    // Filtro por etiqueta
    if (tagId != null) {
      whereClauses.add(
        'id IN (SELECT noteId FROM note_tags WHERE tagId = ?)',
      );
      whereArgs.add(tagId);
    }

    // Filtro por favoritos
    if (onlyFavorites) {
      whereClauses.add('isFavorite = 1');
    }

    // Filtro por fechas
    if (startDate != null) {
      whereClauses.add('DATE(reminderDate) >= DATE(?)');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('DATE(reminderDate) <= DATE(?)');
      whereArgs.add(endDate.toIso8601String());
    }

    // Combinar las cláusulas WHERE
    final whereString =
        whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    // Ejecutar la consulta
    return await db.query(
      'notes',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
  }

  Future<List<Map<String, dynamic>>> queryFavoriteNotes() async {
    final db = await instance.database;
    return await db.query('notes', where: 'isFavorite = ?', whereArgs: [1]);
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(_tableName, row);
  }

  // Actualizar una nota existente
  Future<int> updateNote(int id, Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.update(
      'notes',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    Database db = await instance.database;
    return await db.query(_tableName);
  }

  Future<List<Map<String, dynamic>>> queryNotesByCategoryAndSearch(
      int? categoryId, String searchText) async {
    Database db = await instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    // Filtrar por categoría si está seleccionada
    if (categoryId != null) {
      whereClause += 'categoryId = ?';
      whereArgs.add(categoryId);
    }

    // Filtrar por texto de búsqueda
    if (searchText.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += '(title LIKE ? OR content LIKE ?)';
      whereArgs.add('%$searchText%');
      whereArgs.add('%$searchText%');
    }

    return await db.query(
      'notes',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );
  }

  // Insertar una categoría
  Future<int> insertCategory(String name, int color, String icon) async {
    final db = await instance.database;
    return await db.insert('categories', {
      'name': name,
      'color': color,
      'icon': icon,
    });
  }

  // Obtener todas las categorías
  Future<List<Map<String, dynamic>>> queryAllCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  // Actualizar una categoría
  Future<int> updateCategory(int id, String name, int color, String icon) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      {
        'name': name,
        'color': color,
        'icon': icon,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Eliminar una categoría
  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> queryCategoryById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

}
