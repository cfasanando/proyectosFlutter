import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import '../main.dart'; // Asegúrate de que la ruta sea correcta
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // Importa 'dart:io' para usar 
import '../utils/notification_helper.dart';

class AddNotePage extends StatefulWidget {
  final Map<String, dynamic>? note; // Parámetro opcional para editar una nota

  const AddNotePage({Key? key, this.note}) : super(key: key);

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
   final TextEditingController _tagController = TextEditingController();

  List<Map<String, dynamic>> categories = [];
  List<String> tags = []; // Etiquetas disponibles
  List<String> selectedTags = []; // Etiquetas seleccionadas
  int? selectedCategoryId;
  DateTime? selectedDate; // Variable para almacenar la fecha y hora del recordatorio
  List<String> selectedFilePaths = [];

  @override
  void initState() {
    super.initState();
    fetchCategories();
    fetchTags();

    // Si se está editando una nota, llena los campos
    if (widget.note != null) {
      _titleController.text = widget.note!['title'];
      _contentController.text = widget.note!['content'];
      selectedCategoryId = widget.note!['categoryId'];

       // Manejo de etiquetas (convertir de Map a String)
      if (widget.note!['tags'] != null) {
        selectedTags = List<String>.from(
          widget.note!['tags'].map((tag) => tag['name']), // Convierte cada tag a su nombre
        );
      }

      // Carga la fecha y hora del recordatorio
      if (widget.note!['reminderDate'] != null) {
        selectedDate = DateTime.parse(widget.note!['reminderDate']);
      }

      // Cargar la hora si existe
      if (widget.note!['reminderTime'] != null) {
        final timeParts = widget.note!['reminderTime'].split(':');
        if (timeParts.length == 2) {
          selectedDate = selectedDate?.copyWith(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }

      // Cargar adjuntos
      DBHelper.instance.queryAttachments(widget.note!['id']).then((attachments) {
        if (attachments.isNotEmpty) {
          setState(() {
            selectedFilePaths = attachments.map((e) => e['filePath'] as String).toList();
          });
        }
      });
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedDate != null
          ? TimeOfDay(hour: selectedDate!.hour, minute: selectedDate!.minute)
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        selectedDate = DateTime(
          selectedDate?.year ?? now.year,
          selectedDate?.month ?? now.month,
          selectedDate?.day ?? now.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> scheduleNotification(int noteId, String title, String content) async {
    if (selectedDate != null) {
      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(selectedDate!, tz.local);
      await NotificationHelper().scheduleNotification(
        id: noteId,
        title: title,
        body: content,
        scheduledDate: scheduledDate,
      );
    }
  }

  Future<void> fetchCategories() async {
    final data = await DBHelper.instance.queryAllCategories();
    setState(() {
      categories = data;
    });
  }

  Future<void> fetchTags() async {
    // Suponiendo que existe una función para obtener todas las etiquetas
    final data = await DBHelper.instance.queryAllTags();
    setState(() {
      tags = data.map((e) => e['name'] as String).toList();
    });
  }

  Future<void> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx', 'txt'],
    );

    if (result != null) {
      setState(() {
        selectedFilePaths.addAll(result.paths.whereType<String>());
      });
    }
  }

  Future<void> saveNote() async {
    final title = _titleController.text;
    final content = _contentController.text;

    if (title.isNotEmpty && content.isNotEmpty) {
      final dbHelper = DBHelper.instance;
      final noteData = {
        'title': title,
        'content': content,
        'categoryId': selectedCategoryId,
        'reminderDate': selectedDate != null ? selectedDate!.toIso8601String().split('T')[0] : null, // Solo fecha
        'reminderTime': selectedDate != null
            ? '${selectedDate!.hour.toString().padLeft(2, '0')}:${selectedDate!.minute.toString().padLeft(2, '0')}'
            : null, // Solo hora
      };

      int noteId;
      if (widget.note == null) {
        // Insertar una nueva nota
        noteId = await dbHelper.insert(noteData);
      } else {
        // Actualizar una nota existente
        noteId = widget.note!['id'];
        await dbHelper.updateNote(noteId, noteData);

        // Eliminar archivos adjuntos antiguos
        await dbHelper.deleteAttachmentsForNote(noteId);
      }

      // Guardar nuevos archivos adjuntos
      for (String filePath in selectedFilePaths) {
        await dbHelper.insertAttachment(noteId, filePath);
      }

      // Relacionar etiquetas con la nota
      for (String tag in selectedTags) {
        final tagId = await dbHelper.insertTag(tag); // Inserta o recupera el ID de la etiqueta
        await dbHelper.attachTagToNote(noteId, tagId); // Crea la relación nota-etiqueta
      }

      // Reprogramar notificaciones si se seleccionó una fecha
      if (selectedDate != null) {
        await scheduleNotification(noteId, title, content);
      }

      Navigator.pop(context, true);
    }
  }
  
  Future<void> addTag(String tag) async {
    setState(() {
      if (!tags.contains(tag)) {
        tags.add(tag);
      }
      if (!selectedTags.contains(tag)) {
        selectedTags.add(tag);
      }
    });
    _tagController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.note == null ? 'Agregar Nota' : 'Editar Nota')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: 
          Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(labelText: 'Contenido'),
              ),
              DropdownButton<int>(
                value: selectedCategoryId,
                isExpanded: true,
                hint: const Text('Seleccionar Categoría'),
                items: categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category['id'],
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Color(int.tryParse(category['color'].toString()) ?? 0xFF9E9E9E),
                          child: Icon(Icons.category, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(category['name']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8.0,
                children: selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () {
                      setState(() {
                        selectedTags.remove(tag);
                      });
                    },
                  );
                }).toList(),
              ),
              TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Agregar etiqueta',
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () => addTag(_tagController.text),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Botones para seleccionar fecha y hora
              TextButton(
                onPressed: () => selectDate(context),
                child: Text(
                  selectedDate == null
                      ? 'Seleccionar Fecha'
                      : 'Fecha: ${selectedDate!.toLocal()}'.split(' ')[0],
                ),
              ),
              TextButton(
                onPressed: () => selectTime(context),
                child: Text(
                  selectedDate == null
                      ? 'Seleccionar Hora'
                      : 'Hora: ${selectedDate!.hour.toString().padLeft(2, '0')}:${selectedDate!.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 20),              
              ElevatedButton.icon(
                onPressed: pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Adjuntar Archivo'),
              ),
              if (selectedFilePaths.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Archivos Adjuntos:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...selectedFilePaths.map((filePath) {
                      final fileName = filePath.split('/').last;
                      final isImage = filePath.endsWith('.jpg') ||
                          filePath.endsWith('.png') ||
                          filePath.endsWith('.jpeg');
                      return ListTile(
                        leading: isImage
                            ? Image.file(File(filePath), width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.insert_drive_file),
                        title: Text(fileName),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selectedFilePaths.remove(filePath);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              const SizedBox(height: 20), 
              ElevatedButton(
                onPressed: saveNote,
                child: const Text('Guardar'),
              ),
            ],
          ),
      ),
    );
  }
}
