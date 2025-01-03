import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'db/db_helper.dart';
import 'utils/google_drive_helper.dart';
import 'utils/notification_helper.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/note_details_page.dart';
import 'pages/auth_screen.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa NotificationHelper
  final NotificationHelper notificationHelper = NotificationHelper();
  await notificationHelper.initialize();

  // Inicializa GoogleDriveHelper
  final googleDriveHelper = GoogleDriveHelper();

  // Autenticación de Google Drive
  final credentials = await File('assets/credentials.json').readAsString();
  await googleDriveHelper.authenticate(credentials);

  // Inicializa las zonas horarias
  tz.initializeTimeZones();

  // Configuración inicial de notificaciones locales
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                NoteDetailsPage(noteId: int.parse(response.payload!)),
          ),
        );
      }
    },
  );

  // Leer preferencia de modo oscuro
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  final isPinEnabled = prefs.getBool('isPinEnabled') ?? false;

  runApp(MyApp(
    googleDriveHelper: googleDriveHelper,
    isDarkMode: isDarkMode,
    requireAuth: isPinEnabled,
  ));
}

class MyApp extends StatefulWidget {
  final GoogleDriveHelper googleDriveHelper;
  final bool isDarkMode;
  final bool requireAuth; // Este es el parámetro adicional

  const MyApp({
    Key? key,
    required this.googleDriveHelper,
    required this.isDarkMode,
    required this.requireAuth, // Inclúyelo aquí
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;
  bool _requireAuth = false; // Indica si se necesita autenticación
  bool _authenticated = false; // Indica si el usuario ya autenticó

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _loadAuthPreference();
  }

  Future<void> _loadAuthPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _requireAuth = prefs.getBool('isPinEnabled') ?? false;
    });
  }

  void _toggleTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _authenticated = true; // Marcamos al usuario como autenticado
    });
  }

  @override
  Widget build(BuildContext context) {

    if (_requireAuth && !_authenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Notas con Recordatorios',
        theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
        home: AuthScreen(
          onAuthenticated: _onAuthenticated, // Autentica al usuario
        ),
      );
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Notas con Recordatorios',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: HomePage(
        googleDriveHelper: widget.googleDriveHelper,
        onSettingsPressed: () {
          Navigator.push(
            navigatorKey.currentContext!,
            MaterialPageRoute(
              builder: (context) => SettingsPage(
                isDarkMode: _isDarkMode,
                onThemeChanged: _toggleTheme,
              ),
            ),
          );
        },
      ),
    );
  }
}
