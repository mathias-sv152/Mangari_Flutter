import 'dart:async';
import 'package:mangari/infrastructure/database/database_service.dart';
import 'package:mangari/infrastructure/services/download_service.dart';
import 'package:mangari/domain/entities/saved_manga_entity.dart';
import 'package:mangari/domain/entities/downloaded_chapter_entity.dart';
import 'package:mangari/domain/entities/manga_detail_entity.dart';
import 'package:mangari/domain/entities/chapter_entity.dart';

/// Servicio de alto nivel que coordina la gestión de la biblioteca de mangas
class LibraryService {
  final DatabaseService _databaseService;
  final DownloadService _downloadService;

  // StreamController para notificar cambios en la biblioteca
  final _libraryChangesController =
      StreamController<LibraryChangeEvent>.broadcast();

  /// Stream para escuchar cambios en la biblioteca
  Stream<LibraryChangeEvent> get libraryChanges =>
      _libraryChangesController.stream;

  LibraryService({
    required DatabaseService databaseService,
    required DownloadService downloadService,
  }) : _databaseService = databaseService,
       _downloadService = downloadService;

  /// Libera recursos cuando el servicio se destruye
  void dispose() {
    _libraryChangesController.close();
  }

  // ========== GESTIÓN DE CATEGORÍAS ==========

  /// Obtiene todas las categorías
  Future<List<String>> getCategories() async {
    return await _databaseService.getCategories();
  }

  /// Crea una nueva categoría
  Future<void> createCategory(String name) async {
    await _databaseService.createCategory(name);

    // Notificar cambio
    _libraryChangesController.add(
      LibraryChangeEvent(type: LibraryChangeType.categoryAdded, category: name),
    );
  }

  /// Elimina una categoría
  Future<void> deleteCategory(String name) async {
    await _databaseService.deleteCategory(name);

    // Notificar cambio
    _libraryChangesController.add(
      LibraryChangeEvent(
        type: LibraryChangeType.categoryDeleted,
        category: name,
      ),
    );
  }

  /// Verifica si existe una categoría
  Future<bool> categoryExists(String name) async {
    return await _databaseService.categoryExists(name);
  }

  // ========== GESTIÓN DE MANGAS GUARDADOS ==========

  /// Guarda un manga en la biblioteca
  Future<bool> saveManga({
    required MangaDetailEntity manga,
    required String serverName,
    String category = 'Predeterminado',
  }) async {
    try {
      // Limpiar y normalizar IDs (trim + lowercase para serverId)
      final cleanMangaId = manga.id.trim();
      final cleanServiceId = manga.service.trim().toLowerCase();

      // Verificar si el manga ya existe
      final existingManga = await _databaseService.getSavedManga(
        cleanMangaId,
        cleanServiceId,
      );

      if (existingManga != null) {
        // Si el manga existe pero está en otra categoría, moverlo
        if (existingManga.category != category) {
          print(
            '📦 LibraryService: Moviendo manga de "${existingManga.category}" a "$category"',
          );

          await _databaseService.moveMangaToCategory(
            mangaId: cleanMangaId,
            serverId: cleanServiceId,
            newCategory: category,
          );

          // Notificar que el manga se movió
          final event = LibraryChangeEvent(
            type: LibraryChangeType.mangaMoved,
            mangaId: cleanMangaId,
            serverId: cleanServiceId,
            category: category,
            oldCategory: existingManga.category,
          );

          print('📡 LibraryService: Emitiendo evento: $event');
          print(
            '📡 LibraryService: ¿Hay listeners? ${_libraryChangesController.hasListener}',
          );

          _libraryChangesController.add(event);

          print('✅ LibraryService: Evento emitido');
        } else {
          print('ℹ️ LibraryService: Manga ya está en la categoría "$category"');
        }
        return true;
      }

      // Si no existe, crear nuevo manga guardado
      final savedManga = SavedMangaEntity(
        mangaId: cleanMangaId,
        title: manga.title,
        linkImage: manga.linkImage,
        link: manga.link,
        bookType: manga.bookType,
        demography: manga.demography,
        serverName: serverName,
        serverId: cleanServiceId,
        category: category,
        description: manga.description,
        genres: manga.genres,
        author: manga.author,
        status: manga.status,
        savedAt: DateTime.now(),
      );

      await _databaseService.saveManga(savedManga);

      // Notificar que se agregó un nuevo manga
      final event = LibraryChangeEvent(
        type: LibraryChangeType.mangaAdded,
        mangaId: cleanMangaId,
        serverId: cleanServiceId,
        category: category,
      );

      print('📡 LibraryService: Emitiendo evento de manga agregado: $event');
      _libraryChangesController.add(event);
      print('✅ LibraryService: Evento de manga agregado emitido');

      return true;
    } catch (e) {
      print('❌ Error guardando manga: $e');
      return false;
    }
  }

  /// Obtiene todos los mangas guardados
  Future<List<SavedMangaEntity>> getAllSavedMangas() async {
    return await _databaseService.getAllSavedMangas();
  }

  /// Obtiene mangas por categoría
  Future<List<SavedMangaEntity>> getSavedMangasByCategory(
    String category,
  ) async {
    return await _databaseService.getSavedMangasByCategory(category);
  }

  /// Verifica si un manga está guardado
  Future<bool> isMangaSaved(String mangaId, String serverId) async {
    return await _databaseService.isMangaSaved(mangaId, serverId);
  }

  /// Obtiene un manga guardado específico
  Future<SavedMangaEntity?> getSavedManga(
    String mangaId,
    String serverId,
  ) async {
    return await _databaseService.getSavedManga(mangaId, serverId);
  }

  /// Actualiza el progreso de lectura
  Future<void> updateReadingProgress({
    required String mangaId,
    required String serverId,
    String? lastReadChapter,
    String? lastReadEditorial,
    int? lastReadPage,
  }) async {
    await _databaseService.updateReadingProgress(
      mangaId: mangaId,
      serverId: serverId,
      lastReadChapter: lastReadChapter,
      lastReadEditorial: lastReadEditorial,
      lastReadPage: lastReadPage,
    );
  }

  /// Mueve un manga a otra categoría
  Future<void> moveMangaToCategory({
    required String mangaId,
    required String serverId,
    required String newCategory,
  }) async {
    await _databaseService.moveMangaToCategory(
      mangaId: mangaId,
      serverId: serverId,
      newCategory: newCategory,
    );
  }

  /// Elimina un manga guardado
  Future<bool> deleteSavedManga(String mangaId, String serverId) async {
    try {
      // Limpiar y normalizar IDs (trim + lowercase para serverId)
      final cleanMangaId = mangaId.trim();
      final cleanServiceId = serverId.trim().toLowerCase();

      // Obtener el manga antes de eliminarlo para saber su categoría
      final manga = await _databaseService.getSavedManga(
        cleanMangaId,
        cleanServiceId,
      );

      await _databaseService.deleteSavedManga(cleanMangaId, cleanServiceId);

      // Notificar que se eliminó el manga
      if (manga != null) {
        final event = LibraryChangeEvent(
          type: LibraryChangeType.mangaDeleted,
          mangaId: cleanMangaId,
          serverId: cleanServiceId,
          category: manga.category,
        );

        print('📡 LibraryService: Emitiendo evento de manga eliminado: $event');
        _libraryChangesController.add(event);
        print('✅ LibraryService: Evento de manga eliminado emitido');
      }

      return true;
    } catch (e) {
      print('❌ Error eliminando manga: $e');
      return false;
    }
  }

  /// Obtiene el número de mangas en una categoría
  Future<int> getMangaCountByCategory(String category) async {
    return await _databaseService.getMangaCountByCategory(category);
  }

  // ========== GESTIÓN DE DESCARGAS ==========

  /// Descarga un capítulo
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
    return await _downloadService.downloadChapter(
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      serverId: serverId,
      serverName: serverName,
      chapterNumber: chapterNumber,
      chapterTitle: chapterTitle,
      editorialLink: editorialLink,
      editorialName: editorialName,
      onProgress: onProgress,
    );
  }

  /// Descarga múltiples capítulos
  Future<List<DownloadedChapterEntity>> downloadMultipleChapters({
    required String mangaId,
    required String mangaTitle,
    required String serverId,
    required String serverName,
    required List<ChapterEntity> chapters,
    required String editorial, // Editorial seleccionada
    Function(int current, int total, String chapterName)? onChapterProgress,
    Function(double progress, String message)? onDownloadProgress,
  }) async {
    final List<DownloadedChapterEntity> downloaded = [];
    int current = 0;
    final total = chapters.length;

    for (final chapter in chapters) {
      current++;
      onChapterProgress?.call(current, total, chapter.numAndTitleCap);

      // Encontrar la editorial correspondiente
      final editorialEntity = chapter.editorials.firstWhere(
        (e) => e.editorialName == editorial,
        orElse: () => chapter.editorials.first,
      );

      final result = await downloadChapter(
        mangaId: mangaId,
        mangaTitle: mangaTitle,
        serverId: serverId,
        serverName: serverName,
        chapterNumber: chapter.numAndTitleCap,
        chapterTitle: chapter.numAndTitleCap,
        editorialLink: editorialEntity.editorialLink,
        editorialName: editorialEntity.editorialName,
        onProgress: onDownloadProgress,
      );

      if (result != null) {
        downloaded.add(result);
      }
    }

    return downloaded;
  }

  /// Obtiene capítulos descargados de un manga
  Future<List<DownloadedChapterEntity>> getDownloadedChaptersByManga(
    String mangaId,
    String serverId,
  ) async {
    return await _databaseService.getDownloadedChaptersByManga(
      mangaId,
      serverId,
    );
  }

  /// Verifica si un capítulo está descargado
  Future<bool> isChapterDownloaded({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    return await _downloadService.isChapterDownloaded(
      mangaId: mangaId,
      serverId: serverId,
      chapterNumber: chapterNumber,
      editorial: editorial,
    );
  }

  /// Obtiene las páginas de un capítulo descargado
  Future<List<String>> getDownloadedChapterPages({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    return await _downloadService.getDownloadedChapterPages(
      mangaId: mangaId,
      serverId: serverId,
      chapterNumber: chapterNumber,
      editorial: editorial,
    );
  }

  /// Elimina un capítulo descargado
  Future<bool> deleteDownloadedChapter({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    return await _downloadService.deleteDownloadedChapter(
      mangaId: mangaId,
      serverId: serverId,
      chapterNumber: chapterNumber,
      editorial: editorial,
    );
  }

  /// Elimina todos los capítulos descargados de un manga
  Future<bool> deleteAllDownloadedChapters({
    required String mangaId,
    required String mangaTitle,
    required String serverId,
    required String serverName,
  }) async {
    return await _downloadService.deleteAllDownloadedChapters(
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      serverId: serverId,
      serverName: serverName,
    );
  }

  /// Obtiene el tamaño total de las descargas
  Future<int> getTotalDownloadSize() async {
    return await _downloadService.getTotalDownloadSize();
  }

  /// Limpia todas las descargas
  Future<bool> clearAllDownloads() async {
    return await _downloadService.clearAllDownloads();
  }

  // ========== UTILIDADES ==========

  /// Convierte SavedMangaEntity a MangaDetailEntity para navegación
  MangaDetailEntity savedMangaToDetailEntity(SavedMangaEntity savedManga) {
    return MangaDetailEntity(
      title: savedManga.title,
      linkImage: savedManga.linkImage,
      link: savedManga.link,
      bookType: savedManga.bookType,
      demography: savedManga.demography,
      id: savedManga.mangaId,
      service: savedManga.serverId,
      description: savedManga.description,
      genres: savedManga.genres,
      author: savedManga.author,
      status: savedManga.status,
      source: savedManga.serverName, // Usar el nombre del servidor como source
      chapters: const [], // Los capítulos se cargarán dinámicamente
    );
  }

  /// Obtiene estadísticas de la biblioteca
  Future<Map<String, dynamic>> getLibraryStats() async {
    final categories = await getCategories();
    final allMangas = await getAllSavedMangas();
    final downloadSize = await getTotalDownloadSize();

    int totalDownloadedChapters = 0;
    for (final manga in allMangas) {
      final chapters = await getDownloadedChaptersByManga(
        manga.mangaId,
        manga.serverId,
      );
      totalDownloadedChapters += chapters.length;
    }

    return {
      'totalCategories': categories.length,
      'totalMangas': allMangas.length,
      'totalDownloadedChapters': totalDownloadedChapters,
      'downloadSize': downloadSize,
      'downloadSizeMB': (downloadSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }
}

/// Enum para tipos de cambios en la biblioteca
enum LibraryChangeType {
  mangaAdded,
  mangaDeleted,
  mangaMoved,
  categoryAdded,
  categoryDeleted,
}

/// Evento que representa un cambio en la biblioteca
class LibraryChangeEvent {
  final LibraryChangeType type;
  final String? mangaId;
  final String? serverId;
  final String? category;
  final String? oldCategory;

  LibraryChangeEvent({
    required this.type,
    this.mangaId,
    this.serverId,
    this.category,
    this.oldCategory,
  });

  @override
  String toString() {
    return 'LibraryChangeEvent(type: $type, mangaId: $mangaId, category: $category, oldCategory: $oldCategory)';
  }
}
