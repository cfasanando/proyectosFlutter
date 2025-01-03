import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../db/db_helper.dart';
import '../models/note_model.dart';
import 'add_note_page.dart';
import 'categories_page.dart';
import 'note_details_page.dart';
import '../utils/google_drive_helper.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  final GoogleDriveHelper googleDriveHelper;
  final VoidCallback onSettingsPressed;

  const HomePage({Key? key, required this.googleDriveHelper, required this.onSettingsPressed})
      : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  List<Note> notes = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> tags = []; // Lista de etiquetas

  int? selectedCategoryId;
  int? selectedTagId; // Etiqueta seleccionada
  String searchText = ''; // Texto de búsqueda
  bool onlyFavorites = false;
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchTags();
    fetchNotes();
  }

  Future<void> fetchCategories() async {
    final data = await DBHelper.instance.queryAllCategories();
    setState(() {
      categories = data;
    });
  }

  Future<void> fetchTags() async {
    final data = await DBHelper.instance.queryAllTags();
    setState(() {
      tags = data;
    });
  }

  Future<void> fetchNotes() async {
    final dbHelper = DBHelper.instance;

    final notesList = await dbHelper.queryNotesWithAdvancedFilters(
      searchText: searchText,
      categoryId: selectedCategoryId,
      tagId: selectedTagId,
      onlyFavorites: onlyFavorites,
      startDate: startDate,
      endDate: endDate,
    );

    setState(() {
      notes = notesList.map((note) => Note.fromMap(note)).toList();
    });
  }

  Color _getCategoryColor(dynamic categoryId) {
    if (categoryId == null) return Colors.grey; // Color predeterminado si no hay categoría

    final category = categories.firstWhere(
      (cat) => cat['id'] == categoryId,
      orElse: () => {'color': 0xFF9E9E9E}, // Color gris por defecto si no se encuentra la categoría
    );

    final colorValue = category['color'];
    if (colorValue is int) {
      return Color(colorValue);
    } else if (colorValue is String) {
      return Color(int.parse(colorValue));
    } else {
      return Colors.grey; // Color predeterminado en caso de error
    }
  }

  Future<void> listFilesAndShowDialog(BuildContext context) async {
    try {
      final files = await widget.googleDriveHelper.listFiles();
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Archivos en Google Drive'),
            content: files.isEmpty
                ? const Text('No se encontraron archivos.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: files.map((file) {
                      return ListTile(
                        title: Text(file.name ?? 'Sin Nombre'),
                        subtitle: Text(file.id ?? 'Sin ID'),
                        trailing: IconButton(
                          icon: Icon(Icons.download),
                          onPressed: () async {
                            Navigator.of(context).pop(); // Cierra el diálogo
                            final dir = await getApplicationDocumentsDirectory();
                            final filePath = '${dir.path}/${file.name}';
                            try {
                              await widget.googleDriveHelper.downloadFile(file.id!, filePath);
                              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                                SnackBar(content: Text("Archivo descargado: ${file.name}")),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                                SnackBar(content: Text("Error al descargar: $e")),
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error al mostrar archivos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al listar archivos: $e')),
      );
    }
  }

  Future<void> exportAndShareNotes() async {
    try {
      // Generar el archivo JSON con las notas
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/exported_notes.json';
      final notesJson = notes.map((note) => note.toMap()).toList();
      final file = File(filePath);
      await file.writeAsString(jsonEncode(notesJson));

      // Compartir el archivo
      final xFile = XFile(filePath);
      await Share.shareXFiles([xFile], text: 'Aquí están mis notas exportadas.');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar las notas: $e')),
      );
    }
  }

  Future<void> generateAndSharePdf() async {
    try {
      final pdf = pw.Document();

      // Agregar contenido al PDF
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: notes.map((note) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'Título: ${note.title}\nContenido: ${note.content}',
                  style: pw.TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
          ),
        ),
      );

      // Guardar el archivo PDF
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/notas_exportadas.pdf';    
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // Validar si el archivo fue creado
      if (!await file.exists()) {
        print('El archivo PDF no fue encontrado.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Archivo PDF no encontrado.')),
        );
        return;
      }

      // Imprimir la ruta completa del archivo en la consola
      print('PDF generado en la ruta: $filePath');

      // Usar Share para compartir el archivo PDF
      final xFile = XFile(filePath);
      if (await File(filePath).exists()) {
        print('El archivo PDF existe en: $filePath');
        try {
          await Share.shareXFiles(
            [xFile],
            text: 'Aquí están mis notas exportadas en formato PDF.',
          );
          print('Compartiendo el archivo...');
        } catch (e) {
          print('Error al compartir el archivo: $e');
        }
      } else {
        print('El archivo PDF no se encuentra en la ruta especificada.');
      }

      // Mostrar mensaje de éxito    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF generado y enviado para compartir.')),
      );
    } catch (e) {
      print('Error al generar o compartir el PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar o compartir el PDF: $e')),
      );
    }
  }

  void openFiltersDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Variables temporales para almacenar los filtros
        int? tempCategoryId = selectedCategoryId;
        int? tempTagId = selectedTagId;
        bool tempOnlyFavorites = onlyFavorites;
        DateTime? tempStartDate = startDate;
        DateTime? tempEndDate = endDate;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filtros Avanzados'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown para Categorías
                    DropdownButton<int>(
                      value: tempCategoryId,
                      isExpanded: true,
                      hint: const Text('Filtrar por Categoría'),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: const Text('Todos'),
                        ),
                        ...categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category['id'],
                            child: Text(category['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempCategoryId = value;
                        });
                      },
                    ),
                    // Dropdown para Etiquetas
                    DropdownButton<int>(
                      value: tempTagId,
                      isExpanded: true,
                      hint: const Text('Filtrar por Etiqueta'),
                      items: [
                        DropdownMenuItem<int>(
                          value: null,
                          child: const Text('Todos'),
                        ),
                        ...tags.map((tag) {
                          return DropdownMenuItem<int>(
                            value: tag['id'],
                            child: Text(tag['name']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempTagId = value;
                        });
                      },
                    ),
                    // Interruptor de Solo Favoritos
                    SwitchListTile(
                      title: const Text('Solo Favoritos'),
                      value: tempOnlyFavorites,
                      onChanged: (value) {
                        setState(() {
                          tempOnlyFavorites = value; // Actualiza el estado temporal
                        });
                      },
                    ),
                    // Selección de Fecha Inicial
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: tempStartDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            tempStartDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        tempStartDate == null
                            ? 'Seleccionar Fecha Inicial'
                            : 'Fecha Inicial: ${tempStartDate!.toLocal()}'.split(' ')[0],
                      ),
                    ),
                    // Selección de Fecha Final
                    TextButton(
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: tempEndDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setState(() {
                            tempEndDate = pickedDate;
                          });
                        }
                      },
                      child: Text(
                        tempEndDate == null
                            ? 'Seleccionar Fecha Final'
                            : 'Fecha Final: ${tempEndDate!.toLocal()}'.split(' ')[0],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Actualiza los valores al aplicar
                    setState(() {
                      selectedCategoryId = tempCategoryId;
                      selectedTagId = tempTagId;
                      onlyFavorites = tempOnlyFavorites;
                      startDate = tempStartDate;
                      endDate = tempEndDate;
                    });
                    fetchNotes(); // Recarga las notas
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: widget.onSettingsPressed,
            tooltip: 'Configuración',
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CategoriesPage()),
              );
              fetchCategories();
              fetchNotes();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: () async {
              final dir = await getApplicationDocumentsDirectory();
              final filePath = '${dir.path}/notes.json';
              final notesJson = notes.map((note) => note.toMap()).toList();
              final file = File(filePath);
              await file.writeAsString(jsonEncode(notesJson));
              await widget.googleDriveHelper.uploadFile(filePath, "notes.json");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Notas subidas a Google Drive")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generateAndSharePdf,
            tooltip: 'Exportar como PDF',
          ),
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () async {
              await listFilesAndShowDialog(context);
            },
            tooltip: 'Listar Archivos',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: openFiltersDialog,
            tooltip: 'Filtros Avanzados',
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    searchText = ''; // Reinicia el texto de búsqueda
                    selectedCategoryId = null; // Elimina el filtro de categoría
                    selectedTagId = null; // Elimina el filtro de etiquetas
                    onlyFavorites = false; // Muestra todas las notas, no solo favoritas
                    startDate = null; // Reinicia la fecha inicial
                    endDate = null; // Reinicia la fecha final
                    fetchNotes(); // Recupera todas las notas
                  });
                },
                child: const Text('Mostrar Todos'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final favoriteNotes = await DBHelper.instance.queryFavoriteNotes();
                  setState(() {
                    notes = favoriteNotes.map((note) => Note.fromMap(note)).toList();
                  });
                },
                child: const Text('Favoritos'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                  fetchNotes();
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final categoryColor = _getCategoryColor(note.categoryId);

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor,
                    child: Text(
                      note.title.substring(0, 1), // Inicial de la nota
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(note.title),
                  subtitle: Text(note.content),
                  trailing: IconButton(
                    icon: Icon(
                      note.isFavorite ? Icons.star : Icons.star_border,
                      color: note.isFavorite ? Colors.yellow : null,
                    ),
                    onPressed: () async {
                      await DBHelper.instance.toggleFavorite(note.id!, !note.isFavorite);
                      fetchNotes(); // Actualiza la lista después de cambiar el estado
                    },
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteDetailsPage(noteId: note.id!),
                      ),
                    );
                    if (result == true) {
                      fetchNotes();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddNotePage()),
          );
          if (result == true) {
            await fetchNotes(); // Recarga las notas al regresar
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
