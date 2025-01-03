import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:path_provider/path_provider.dart';

class GoogleDriveHelper {
  final _scopes = [drive.DriveApi.driveFileScope];
  late AuthClient _client;

  // Método para autenticar al usuario
  Future<void> authenticate(String credentialsJson) async {
    final accountCredentials = ServiceAccountCredentials.fromJson(credentialsJson);
    _client = await clientViaServiceAccount(accountCredentials, _scopes);
  }

  // Método para subir un archivo a Google Drive
  Future<void> uploadFile(String localFilePath, String fileName) async {
    final driveApi = drive.DriveApi(_client);

    // Crea un objeto de archivo para Google Drive
    final file = drive.File()..name = fileName;

    // Lee el archivo local
    final localFile = File(localFilePath);
    final media = drive.Media(localFile.openRead(), localFile.lengthSync());

    // Sube el archivo a Google Drive
    final uploadedFile = await driveApi.files.create(file, uploadMedia: media);
    print("Archivo subido correctamente a Google Drive con ID: ${uploadedFile.id}");

    // Verifica que el ID del archivo no sea nulo
    if (uploadedFile.id == null) {
      throw Exception("No se pudo obtener el ID del archivo subido.");
    }

    // Crea un permiso para compartir el archivo con tu cuenta personal
    final permission = drive.Permission()
      ..type = 'user'
      ..role = 'writer'
      ..emailAddress = 'christian1827@gmail.com'; // Cambia este correo por el tuyo.

    try {
      // Asigna el permiso al archivo subido
      await driveApi.permissions.create(
        permission,        // El objeto Permission va primero
        uploadedFile.id!,  // Luego el ID del archivo
        sendNotificationEmail: true,  // Opcional: enviar notificación por correo
        $fields: 'id',                // Solo obtener el ID del permiso en la respuesta
      );
      print("Archivo compartido con tu cuenta personal.");
    } catch (e) {
      print("Error al asignar permiso: $e");
    }
  }

  // Método para descargar un archivo desde Google Drive
  Future<void> downloadFile(String fileId, String savePath) async {
    final driveApi = drive.DriveApi(_client);

    try {
      final file = File(savePath);
      final fileStream = file.openWrite();

      // Descarga el archivo
      final drive.Media fileMedia = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Guarda el archivo en el sistema
      await fileMedia.stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      print("Archivo descargado correctamente en: $savePath");
    } catch (e) {
      print("Error al descargar: $e");
      rethrow;
    }
  }

  Future<List<drive.File>> listFiles() async {
    final driveApi = drive.DriveApi(_client);

    try {
      final fileList = await driveApi.files.list();
      return fileList.files ?? []; // Devuelve una lista vacía si no hay archivos
    } catch (e) {
      print("Error al listar archivos: $e");
      return []; // Devuelve una lista vacía en caso de error
    }
  }

}
