import 'dart:io';
import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'add_note_page.dart';

class NoteDetailsPage extends StatelessWidget {
  final int noteId;

  const NoteDetailsPage({Key? key, required this.noteId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DBHelper.instance.queryNoteWithAttachments(noteId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Nota no encontrada')),
            body: const Center(child: Text('No se encontró la nota.')),
          );
        } else {
          final note = snapshot.data!;
          final tags = (note['tags'] as List<Map<String, dynamic>>?) ?? [];
          final attachments = note['attachments'] != null
              ? List<Map<String, dynamic>>.from(note['attachments'])
              : [];

          return Scaffold(
            appBar: AppBar(
              title: Text(note['title']),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddNotePage(note: note),
                      ),
                    ).then((value) {
                      if (value == true) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Eliminar Nota'),
                          content: const Text(
                              '¿Estás seguro de que deseas eliminar esta nota?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirm == true) {
                      await DBHelper.instance.deleteNote(note['id']);
                      Navigator.pop(context, true);
                    }
                  },
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    note['content'],
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  if (note['categoryName'] != null)
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Color(note['categoryColor'] ?? 0xFF9E9E9E),
                          child: Icon(
                            IconData(
                              int.tryParse(note['categoryIcon'] ?? '0') ?? Icons.category.codePoint,
                              fontFamily: 'MaterialIcons',
                            ),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          note['categoryName'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  if (note['reminderDate'] != null || note['reminderTime'] != null)
                    Text(
                      'Recordatorio: ${note['reminderDate'] ?? ''} ${note['reminderTime'] ?? ''}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  if (tags.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text('Etiquetas:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Wrap(
                          spacing: 8.0,
                          children: tags.map((tag) {
                            return Chip(label: Text(tag['name']));
                          }).toList(),
                        ),
                      ],
                    ),
                  if (attachments.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Archivos Adjuntos:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...attachments.map((attachment) {
                          final filePath = attachment['filePath'] as String;
                          final fileName = filePath.split('/').last;
                          final isImage = filePath.endsWith('.jpg') ||
                              filePath.endsWith('.png') ||
                              filePath.endsWith('.jpeg');

                          return ListTile(
                            leading: isImage
                                ? Image.file(File(filePath),
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover)
                                : const Icon(Icons.insert_drive_file),
                            title: Text(fileName),
                            trailing: IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('$fileName descargado')),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
