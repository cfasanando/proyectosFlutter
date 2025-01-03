import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Asegúrate de agregar esta dependencia
import '../db/db_helper.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({Key? key}) : super(key: key);

  @override
  _CategoriesPageState createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> categories = [];

  // Lista fija de íconos disponibles
  final Map<String, IconData> availableIcons = {
    'category': Icons.category,
    'work': Icons.work,
    'home': Icons.home,
    'school': Icons.school,
    'alarm': Icons.alarm,
    'event': Icons.event,
    'shopping': Icons.shopping_cart,
    'favorite': Icons.favorite,
    'fitness': Icons.fitness_center,
    'travel': Icons.flight,
    'music': Icons.music_note,
    'photo': Icons.photo,
    'game': Icons.videogame_asset,
    'chat': Icons.chat,
    'book': Icons.book,
  };

  int selectedColor = 0xFF2196F3; // Color predeterminado
  String selectedIcon = 'category'; // Ícono predeterminado

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final data = await DBHelper.instance.queryAllCategories();
    setState(() {
      categories = data.map((category) {
        return {
          'id': category['id'] is int ? category['id'] : int.tryParse(category['id']),
          'name': category['name'],
          'color': category['color'] is int ? category['color'] : int.tryParse(category['color']),
          'icon': category['icon'],
        };
      }).toList();
    });
  }

  Future<void> addOrEditCategory({Map<String, dynamic>? category}) async {
    if (category != null) {
      _controller.text = category['name'];
      selectedColor = category['color'];
      selectedIcon = category['icon'];
    } else {
      _controller.clear();
      selectedColor = 0xFF2196F3;
      selectedIcon = 'category';
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(category == null ? 'Nueva Categoría' : 'Editar Categoría'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(labelText: 'Nombre de la Categoría'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => selectColor(context, setStateDialog),
                      child: const Text('Seleccionar Color'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () async {
                        final selected = await showIconPicker(context);
                        if (selected != null) {
                          setStateDialog(() {
                            selectedIcon = selected;
                          });
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(availableIcons[selectedIcon]),
                          const SizedBox(width: 10),
                          Text('Icono Seleccionado: $selectedIcon'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_controller.text.isNotEmpty) {
                      if (category == null) {
                        await DBHelper.instance.insertCategory(
                          _controller.text,
                          selectedColor,
                          selectedIcon,
                        );
                      } else {
                        await DBHelper.instance.updateCategory(
                          category['id'],
                          _controller.text,
                          selectedColor,
                          selectedIcon,
                        );
                      }
                      await fetchCategories();
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> showIconPicker(BuildContext context) async {
    return await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Ícono'),
          content: SizedBox(
            height: 300, // Altura fija para evitar problemas de tamaño
            width: double.maxFinite,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: availableIcons.length,
              itemBuilder: (context, index) {
                final iconName = availableIcons.keys.elementAt(index);
                final iconData = availableIcons.values.elementAt(index);

                return GestureDetector(
                  onTap: () => Navigator.pop(context, iconName),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        iconName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void selectColor(BuildContext context, void Function(void Function()) setStateDialog) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: Color(selectedColor),
              onColorChanged: (color) {
                setStateDialog(() {
                  selectedColor = color.value;
                });
              },
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(category['color']),
                    child: Icon(
                      availableIcons[category['icon']],
                      color: Colors.white,
                    ),
                  ),
                  title: Text(category['name']),
                  subtitle: Text('Icono: ${category['icon']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => addOrEditCategory(category: category),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => deleteCategory(category['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nueva Categoría'),
              onPressed: () => addOrEditCategory(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> deleteCategory(int id) async {
    await DBHelper.instance.deleteCategory(id);
    fetchCategories();
  }
}
