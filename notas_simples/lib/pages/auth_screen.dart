import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({Key? key, required this.onAuthenticated}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _pinController = TextEditingController();
  String? _storedPin;

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storedPin = prefs.getString('userPin');
    });
  }

  void _validatePin() {
    if (_pinController.text == _storedPin) {
      widget.onAuthenticated();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrecto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autenticación')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Ingresa tu PIN para acceder', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _validatePin,
              child: const Text('Acceder'),
            ),
          ],
        ),
      ),
    );
  }
}
