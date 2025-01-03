import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsPage({Key? key, required this.isDarkMode, required this.onThemeChanged})
      : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;
  bool _isPinEnabled = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPinEnabled = prefs.getBool('isPinEnabled') ?? false;
    });
  }

  Future<void> _togglePinProtection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final pin = await _showSetPinDialog();
      if (pin != null) {
        await prefs.setString('userPin', pin);
        setState(() {
          _isPinEnabled = true;
        });
      }
    } else {
      await prefs.remove('userPin');
      setState(() {
        _isPinEnabled = false;
      });
    }
    await prefs.setBool('isPinEnabled', _isPinEnabled);
  }

  Future<String?> _showSetPinDialog() async {
    final TextEditingController pinController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Establecer PIN'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Ingresa un PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, pinController.text);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    widget.onThemeChanged(value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Modo oscuro'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
            ),
          ),
          ListTile(
            title: const Text('Activar protección por PIN'),
            trailing: Switch(
              value: _isPinEnabled,
              onChanged: _togglePinProtection,
            ),
          ),          
        ],
      ),
    );
  }
}
