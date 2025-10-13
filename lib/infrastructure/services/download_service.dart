import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mangari/infrastructure/database/database_service.dart';
import 'package:mangari/domain/entities/downloaded_chapter_entity.dart';
import 'package:mangari/application/services/servers_service_v2.dart';

/// Servicio para gestionar la descarga de capítulos de manga
class DownloadService {
  final DatabaseService _databaseService;
  final ServersServiceV2 _serversService;
  final Dio _dio = Dio();

  DownloadService({
    required DatabaseService databaseService,
    required ServersServiceV2 serversService,
  }) : _databaseService = databaseService,
       _serversService = serversService;

  /// Obtiene el directorio base para descargas
  Future<Directory> _getDownloadsDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory downloadsDir = Directory(
      path.join(appDocDir.path, 'MangariDownloads'),
    );

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    return downloadsDir;
  }

  /// Obtiene el directorio para un manga específico
  /// Estructura: MangariDownloads/ServerName/MangaName/Chapters/
  Future<Directory> _getMangaDirectory({
    required String serverName,
    required String mangaTitle,
  }) async {
    final baseDir = await _getDownloadsDirectory();

    // Sanitizar nombres para evitar problemas con el sistema de archivos
    final sanitizedServer = _sanitizeFileName(serverName);
    final sanitizedManga = _sanitizeFileName(mangaTitle);

    final Directory mangaDir = Directory(
      path.join(baseDir.path, sanitizedServer, sanitizedManga, 'Chapters'),
    );

    if (!await mangaDir.exists()) {
      await mangaDir.create(recursive: true);
    }

    return mangaDir;
  }

  /// Sanitiza un nombre de archivo para evitar caracteres inválidos
  String _sanitizeFileName(String name) {
    // Reemplazar caracteres inválidos en nombres de archivo
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  /// Descarga un capítulo completo con todas sus páginas
  Future<DownloadedChapterEntity?> downloadChapter({
    required String mangaId,
    required String mangaTitle,
    required String serverId,
    required String serverName,
    required String chapterNumber,
    required String chapterTitle,
    required String editorialLink,
    required String editorialName,
    Function(double progress, String message)? onProgress,
  }) async {
    try {
      onProgress?.call(0.0, 'Iniciando descarga...');

      // Verificar si ya está descargado
      final isDownloaded = await _databaseService.isChapterDownloaded(
        mangaId: mangaId,
        serverId: serverId,
        chapterNumber: chapterNumber,
        editorial: editorialName,
      );

      if (isDownloaded) {
        onProgress?.call(1.0, 'Capítulo ya descargado');
        return await _databaseService.getDownloadedChapter(
          mangaId: mangaId,
          serverId: serverId,
          chapterNumber: chapterNumber,
          editorial: editorialName,
        );
      }

      // Obtener las URLs de las páginas del capítulo
      onProgress?.call(0.1, 'Obteniendo páginas del capítulo...');
      final pages = await _serversService.getChapterImagesFromServer(
        serverId,
        editorialLink,
      );

      if (pages.isEmpty) {
        onProgress?.call(0.0, 'Error: No se encontraron páginas');
        return null;
      }

      // Crear directorio para el capítulo
      final mangaDir = await _getMangaDirectory(
        serverName: serverName,
        mangaTitle: mangaTitle,
      );

      final sanitizedChapter = _sanitizeFileName(chapterNumber);
      final sanitizedEditorial = _sanitizeFileName(editorialName);
      final chapterDir = Directory(
        path.join(mangaDir.path, '${sanitizedChapter}_$sanitizedEditorial'),
      );

      if (!await chapterDir.exists()) {
        await chapterDir.create(recursive: true);
      }

      // Descargar cada página
      int downloadedPages = 0;
      final totalPages = pages.length;

      for (int i = 0; i < totalPages; i++) {
        final pageUrl = pages[i];
        final progress = 0.1 + (0.8 * (i / totalPages));
        onProgress?.call(
          progress,
          'Descargando página ${i + 1} de $totalPages...',
        );

        try {
          // Determinar la extensión del archivo desde la URL
          final uri = Uri.parse(pageUrl);
          String extension = path.extension(uri.path);

          // Si no tiene extensión válida, usar .jpg por defecto
          if (extension.isEmpty || !_isValidImageExtension(extension)) {
            extension = '.jpg';
          }

          final fileName =
              'page_${(i + 1).toString().padLeft(4, '0')}$extension';
          final filePath = path.join(chapterDir.path, fileName);

          // Descargar la imagen
          await _dio.download(
            pageUrl,
            filePath,
            options: Options(
              headers: {
                'Referer': _getRefererForServer(serverId),
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ),
          );

          downloadedPages++;
        } catch (e) {
          print('❌ Error descargando página ${i + 1}: $e');
          // Continuar con las demás páginas
        }
      }

      // Verificar si la descarga está completa
      final isComplete = downloadedPages == totalPages;

      // Guardar en la base de datos
      onProgress?.call(0.95, 'Guardando información...');
      final downloadedChapter = DownloadedChapterEntity(
        mangaId: mangaId,
        serverId: serverId,
        chapterNumber: chapterNumber,
        chapterTitle: chapterTitle,
        editorial: editorialName,
        localPath: chapterDir.path,
        totalPages: downloadedPages,
        downloadedAt: DateTime.now(),
        isComplete: isComplete,
      );

      await _databaseService.saveDownloadedChapter(downloadedChapter);

      onProgress?.call(
        1.0,
        isComplete
            ? 'Descarga completada: $downloadedPages páginas'
            : 'Descarga parcial: $downloadedPages de $totalPages páginas',
      );

      return downloadedChapter;
    } catch (e) {
      print('❌ Error en downloadChapter: $e');
      onProgress?.call(0.0, 'Error: $e');
      return null;
    }
  }

  /// Verifica si una extensión es válida para imágenes
  bool _isValidImageExtension(String extension) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.avif'];
    return validExtensions.contains(extension.toLowerCase());
  }

  /// Obtiene el referer apropiado para cada servidor
  String _getRefererForServer(String serverId) {
    switch (serverId.toLowerCase()) {
      case 'tmo':
        return 'https://lectortmo.com/';
      case 'mangadex':
        return 'https://mangadex.org/';
      default:
        return 'https://mangari.app/';
    }
  }

  /// Obtiene las páginas locales de un capítulo descargado
  Future<List<String>> getDownloadedChapterPages({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    final chapter = await _databaseService.getDownloadedChapter(
      mangaId: mangaId,
      serverId: serverId,
      chapterNumber: chapterNumber,
      editorial: editorial,
    );

    if (chapter == null) return [];

    final chapterDir = Directory(chapter.localPath);
    if (!await chapterDir.exists()) return [];

    // Listar y ordenar archivos
    final files = await chapterDir.list().toList();
    final imageFiles =
        files
            .whereType<File>()
            .where((file) => _isValidImageExtension(path.extension(file.path)))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    return imageFiles.map((file) => file.path).toList();
  }

  /// Elimina un capítulo descargado
  Future<bool> deleteDownloadedChapter({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    try {
      final chapter = await _databaseService.getDownloadedChapter(
        mangaId: mangaId,
        serverId: serverId,
        chapterNumber: chapterNumber,
        editorial: editorial,
      );

      if (chapter == null) return false;

      // Eliminar directorio físico
      final chapterDir = Directory(chapter.localPath);
      if (await chapterDir.exists()) {
        await chapterDir.delete(recursive: true);
      }

      // Eliminar de la base de datos
      await _databaseService.deleteDownloadedChapter(
        mangaId: mangaId,
        serverId: serverId,
        chapterNumber: chapterNumber,
        editorial: editorial,
      );

      return true;
    } catch (e) {
      print('❌ Error eliminando capítulo descargado: $e');
      return false;
    }
  }

  /// Elimina todos los capítulos descargados de un manga
  Future<bool> deleteAllDownloadedChapters({
    required String mangaId,
    required String mangaTitle,
    required String serverId,
    required String serverName,
  }) async {
    try {
      // Obtener todos los capítulos descargados
      final chapters = await _databaseService.getDownloadedChaptersByManga(
        mangaId,
        serverId,
      );

      // Eliminar cada capítulo
      for (final chapter in chapters) {
        final chapterDir = Directory(chapter.localPath);
        if (await chapterDir.exists()) {
          await chapterDir.delete(recursive: true);
        }
      }

      // Eliminar de la base de datos
      await _databaseService.deleteDownloadedChaptersByManga(mangaId, serverId);

      // Intentar eliminar el directorio del manga si está vacío
      try {
        final mangaDir = await _getMangaDirectory(
          serverName: serverName,
          mangaTitle: mangaTitle,
        );
        if (await mangaDir.exists()) {
          final contents = await mangaDir.list().toList();
          if (contents.isEmpty) {
            await mangaDir.delete(recursive: true);
          }
        }
      } catch (e) {
        print('⚠️ No se pudo eliminar el directorio del manga: $e');
      }

      return true;
    } catch (e) {
      print('❌ Error eliminando capítulos descargados: $e');
      return false;
    }
  }

  /// Verifica si un capítulo está descargado
  Future<bool> isChapterDownloaded({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    return await _databaseService.isChapterDownloaded(
      mangaId: mangaId,
      serverId: serverId,
      chapterNumber: chapterNumber,
      editorial: editorial,
    );
  }

  /// Obtiene el tamaño total de las descargas en bytes
  Future<int> getTotalDownloadSize() async {
    try {
      final downloadsDir = await _getDownloadsDirectory();
      if (!await downloadsDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in downloadsDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('❌ Error calculando tamaño de descargas: $e');
      return 0;
    }
  }

  /// Limpia la caché de descargas (elimina todo)
  Future<bool> clearAllDownloads() async {
    try {
      final downloadsDir = await _getDownloadsDirectory();
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }

      // También limpiar registros de la base de datos
      final db = await _databaseService.database;
      await db.delete('downloaded_chapters');

      return true;
    } catch (e) {
      print('❌ Error limpiando descargas: $e');
      return false;
    }
  }
}
