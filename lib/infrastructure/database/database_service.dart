import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:mangari/domain/entities/saved_manga_entity.dart';
import 'package:mangari/domain/entities/downloaded_chapter_entity.dart';

/// Servicio para gestionar la base de datos local de la aplicación
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// Obtiene la instancia de la base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'mangari.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas de la base de datos
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de categorías/tabs
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    // Insertar categoría predeterminada
    await db.insert('categories', {
      'name': 'Predeterminado',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Tabla de mangas guardados
    await db.execute('''
      CREATE TABLE saved_mangas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id TEXT NOT NULL,
        title TEXT NOT NULL,
        link_image TEXT NOT NULL,
        link TEXT NOT NULL,
        book_type TEXT NOT NULL,
        demography TEXT NOT NULL,
        server_name TEXT NOT NULL,
        server_id TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        genres TEXT,
        author TEXT,
        status TEXT,
        last_read_chapter TEXT,
        last_read_editorial TEXT,
        last_read_page INTEGER,
        saved_at TEXT NOT NULL,
        last_read_at TEXT,
        UNIQUE(manga_id, server_id, category)
      )
    ''');

    // Tabla de capítulos descargados
    await db.execute('''
      CREATE TABLE downloaded_chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id TEXT NOT NULL,
        server_id TEXT NOT NULL,
        chapter_number TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        editorial TEXT NOT NULL,
        local_path TEXT NOT NULL,
        total_pages INTEGER NOT NULL,
        downloaded_at TEXT NOT NULL,
        is_complete INTEGER NOT NULL DEFAULT 1,
        UNIQUE(manga_id, server_id, chapter_number, editorial)
      )
    ''');

    // Tabla de progreso de lectura (independiente de saved_mangas)
    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        manga_id TEXT NOT NULL,
        server_id TEXT NOT NULL,
        chapter_id TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        editorial TEXT NOT NULL,
        current_page INTEGER NOT NULL DEFAULT 0,
        total_pages INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_read_at TEXT NOT NULL,
        UNIQUE(manga_id, server_id, chapter_id, editorial)
      )
    ''');

    // Índices para mejorar el rendimiento y optimizar consultas
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_category ON saved_mangas(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_server ON saved_mangas(server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_composite ON saved_mangas(manga_id, server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_downloaded_chapters_manga ON downloaded_chapters(manga_id, server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_manga ON reading_progress(manga_id, server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_chapter ON reading_progress(manga_id, server_id, chapter_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_last_read ON reading_progress(last_read_at)',
    );
  }

  /// Actualiza la base de datos cuando cambia la versión
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migración de versión 1 a 2: Agregar tabla de progreso de lectura
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reading_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          manga_id TEXT NOT NULL,
          server_id TEXT NOT NULL,
          chapter_id TEXT NOT NULL,
          chapter_title TEXT NOT NULL,
          editorial TEXT NOT NULL,
          current_page INTEGER NOT NULL DEFAULT 0,
          total_pages INTEGER NOT NULL DEFAULT 0,
          is_completed INTEGER NOT NULL DEFAULT 0,
          last_read_at TEXT NOT NULL,
          UNIQUE(manga_id, server_id, chapter_id, editorial)
        )
      ''');

      // Crear índices para la nueva tabla
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_progress_manga ON reading_progress(manga_id, server_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_progress_chapter ON reading_progress(manga_id, server_id, chapter_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reading_progress_last_read ON reading_progress(last_read_at)',
      );
    }

    // Asegurar que todos los índices existan (para bases de datos existentes)
    await _ensureIndexesExist(db);
  }

  /// Asegura que todos los índices necesarios existan
  Future<void> _ensureIndexesExist(Database db) async {
    // Índices para saved_mangas
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_category ON saved_mangas(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_server ON saved_mangas(server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_mangas_composite ON saved_mangas(manga_id, server_id)',
    );

    // Índices para downloaded_chapters
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_downloaded_chapters_manga ON downloaded_chapters(manga_id, server_id)',
    );

    // Índices para reading_progress
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_manga ON reading_progress(manga_id, server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_chapter ON reading_progress(manga_id, server_id, chapter_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reading_progress_last_read ON reading_progress(last_read_at)',
    );
  }

  // ========== CATEGORÍAS ==========

  /// Obtiene todas las categorías
  Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'created_at ASC',
    );

    return maps.map((map) => map['name'] as String).toList();
  }

  /// Crea una nueva categoría
  Future<void> createCategory(String name) async {
    final db = await database;
    await db.insert('categories', {
      'name': name,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// Elimina una categoría (solo si no es la predeterminada)
  Future<void> deleteCategory(String name) async {
    if (name == 'Predeterminado') {
      throw Exception('No se puede eliminar la categoría predeterminada');
    }

    final db = await database;

    // Mover mangas de la categoría eliminada a la predeterminada
    await db.update(
      'saved_mangas',
      {'category': 'Predeterminado'},
      where: 'category = ?',
      whereArgs: [name],
    );

    // Eliminar la categoría
    await db.delete('categories', where: 'name = ?', whereArgs: [name]);
  }

  /// Verifica si existe una categoría
  Future<bool> categoryExists(String name) async {
    final db = await database;
    final result = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty;
  }

  // ========== MANGAS GUARDADOS ==========

  /// Guarda un manga en la biblioteca
  Future<int> saveManga(SavedMangaEntity manga) async {
    final db = await database;
    final mangaMap = manga.toMap();

    final result = await db.insert(
      'saved_mangas',
      mangaMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return result;
  }

  /// Obtiene todos los mangas guardados
  Future<List<SavedMangaEntity>> getAllSavedMangas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saved_mangas',
      orderBy: 'saved_at DESC',
    );

    return maps.map((map) => SavedMangaEntity.fromMap(map)).toList();
  }

  /// Obtiene mangas guardados por categoría
  Future<List<SavedMangaEntity>> getSavedMangasByCategory(
    String category,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'saved_mangas',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'last_read_at DESC, saved_at DESC',
    );

    return maps.map((map) => SavedMangaEntity.fromMap(map)).toList();
  }

  /// Obtiene un manga guardado específico
  Future<SavedMangaEntity?> getSavedManga(
    String mangaId,
    String serverId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'saved_mangas',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavedMangaEntity.fromMap(maps.first);
  }

  /// Verifica si un manga está guardado
  Future<bool> isMangaSaved(String mangaId, String serverId) async {
    final manga = await getSavedManga(mangaId, serverId);
    return manga != null;
  }

  /// Actualiza el progreso de lectura de un manga
  Future<void> updateReadingProgress({
    required String mangaId,
    required String serverId,
    String? lastReadChapter,
    String? lastReadEditorial,
    int? lastReadPage,
  }) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'last_read_at': DateTime.now().toIso8601String(),
    };

    if (lastReadChapter != null) {
      updateData['last_read_chapter'] = lastReadChapter;
    }
    if (lastReadEditorial != null) {
      updateData['last_read_editorial'] = lastReadEditorial;
    }
    if (lastReadPage != null) {
      updateData['last_read_page'] = lastReadPage;
    }

    await db.update(
      'saved_mangas',
      updateData,
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
    );
  }

  /// Mueve un manga a otra categoría
  Future<void> moveMangaToCategory({
    required String mangaId,
    required String serverId,
    required String newCategory,
  }) async {
    final db = await database;
    await db.update(
      'saved_mangas',
      {'category': newCategory},
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
    );
  }

  /// Elimina un manga guardado
  Future<void> deleteSavedManga(String mangaId, String serverId) async {
    final db = await database;
    await db.delete(
      'saved_mangas',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
    );

    // También eliminar capítulos descargados asociados
    await deleteDownloadedChaptersByManga(mangaId, serverId);
  }

  /// Obtiene el número de mangas en una categoría
  Future<int> getMangaCountByCategory(String category) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM saved_mangas WHERE category = ?',
      [category],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== CAPÍTULOS DESCARGADOS ==========

  /// Guarda un capítulo descargado
  Future<int> saveDownloadedChapter(DownloadedChapterEntity chapter) async {
    final db = await database;
    return await db.insert(
      'downloaded_chapters',
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene todos los capítulos descargados de un manga
  Future<List<DownloadedChapterEntity>> getDownloadedChaptersByManga(
    String mangaId,
    String serverId,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'downloaded_chapters',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
      orderBy: 'chapter_number ASC',
    );

    return maps.map((map) => DownloadedChapterEntity.fromMap(map)).toList();
  }

  /// Verifica si un capítulo está descargado
  Future<bool> isChapterDownloaded({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    final db = await database;
    final result = await db.query(
      'downloaded_chapters',
      where:
          'manga_id = ? AND server_id = ? AND chapter_number = ? AND editorial = ?',
      whereArgs: [mangaId, serverId, chapterNumber, editorial],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Obtiene un capítulo descargado específico
  Future<DownloadedChapterEntity?> getDownloadedChapter({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'downloaded_chapters',
      where:
          'manga_id = ? AND server_id = ? AND chapter_number = ? AND editorial = ?',
      whereArgs: [mangaId, serverId, chapterNumber, editorial],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return DownloadedChapterEntity.fromMap(maps.first);
  }

  /// Elimina un capítulo descargado
  Future<void> deleteDownloadedChapter({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
  }) async {
    final db = await database;
    await db.delete(
      'downloaded_chapters',
      where:
          'manga_id = ? AND server_id = ? AND chapter_number = ? AND editorial = ?',
      whereArgs: [mangaId, serverId, chapterNumber, editorial],
    );
  }

  /// Elimina todos los capítulos descargados de un manga
  Future<void> deleteDownloadedChaptersByManga(
    String mangaId,
    String serverId,
  ) async {
    final db = await database;
    await db.delete(
      'downloaded_chapters',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId, serverId],
    );
  }

  /// Actualiza el estado de completitud de un capítulo descargado
  Future<void> updateChapterCompletionStatus({
    required String mangaId,
    required String serverId,
    required String chapterNumber,
    required String editorial,
    required bool isComplete,
  }) async {
    final db = await database;
    await db.update(
      'downloaded_chapters',
      {'is_complete': isComplete ? 1 : 0},
      where:
          'manga_id = ? AND server_id = ? AND chapter_number = ? AND editorial = ?',
      whereArgs: [mangaId, serverId, chapterNumber, editorial],
    );
  }

  // ========== PROGRESO DE LECTURA ==========

  /// Guarda o actualiza el progreso de lectura de un capítulo
  Future<void> saveReadingProgress({
    required String mangaId,
    required String serverId,
    required String chapterId,
    required String chapterTitle,
    required String editorial,
    required int currentPage,
    required int totalPages,
    bool? isCompleted,
  }) async {
    final db = await database;

    // Determinar si el capítulo está completado
    final completed =
        isCompleted ?? (currentPage >= totalPages - 1 && totalPages > 0);

    await db.insert('reading_progress', {
      'manga_id': mangaId.trim(),
      'server_id': serverId.trim().toLowerCase(),
      'chapter_id': chapterId.trim(),
      'chapter_title': chapterTitle,
      'editorial': editorial,
      'current_page': currentPage,
      'total_pages': totalPages,
      'is_completed': completed ? 1 : 0,
      'last_read_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Obtiene el progreso de lectura de un capítulo específico
  Future<Map<String, dynamic>?> getReadingProgress({
    required String mangaId,
    required String serverId,
    required String chapterId,
    required String editorial,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_progress',
      where:
          'manga_id = ? AND server_id = ? AND chapter_id = ? AND editorial = ?',
      whereArgs: [
        mangaId.trim(),
        serverId.trim().toLowerCase(),
        chapterId.trim(),
        editorial,
      ],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// Obtiene todos los capítulos leídos de un manga
  Future<List<Map<String, dynamic>>> getReadingProgressByManga({
    required String mangaId,
    required String serverId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reading_progress',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId.trim(), serverId.trim().toLowerCase()],
      orderBy: 'last_read_at DESC',
    );

    return maps;
  }

  /// Verifica si un capítulo está marcado como completado
  Future<bool> isChapterCompleted({
    required String mangaId,
    required String serverId,
    required String chapterId,
    required String editorial,
  }) async {
    final progress = await getReadingProgress(
      mangaId: mangaId,
      serverId: serverId,
      chapterId: chapterId,
      editorial: editorial,
    );

    if (progress == null) return false;
    return progress['is_completed'] == 1;
  }

  /// Marca un capítulo como completado
  Future<void> markChapterAsCompleted({
    required String mangaId,
    required String serverId,
    required String chapterId,
    required String chapterTitle,
    required String editorial,
    required int totalPages,
  }) async {
    await saveReadingProgress(
      mangaId: mangaId,
      serverId: serverId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      editorial: editorial,
      currentPage: totalPages - 1,
      totalPages: totalPages,
      isCompleted: true,
    );
  }

  /// Elimina el progreso de lectura de un capítulo
  Future<void> deleteReadingProgress({
    required String mangaId,
    required String serverId,
    required String chapterId,
    required String editorial,
  }) async {
    final db = await database;
    await db.delete(
      'reading_progress',
      where:
          'manga_id = ? AND server_id = ? AND chapter_id = ? AND editorial = ?',
      whereArgs: [
        mangaId.trim(),
        serverId.trim().toLowerCase(),
        chapterId.trim(),
        editorial,
      ],
    );
  }

  /// Elimina todo el progreso de lectura de un manga
  Future<void> deleteReadingProgressByManga({
    required String mangaId,
    required String serverId,
  }) async {
    final db = await database;
    await db.delete(
      'reading_progress',
      where: 'manga_id = ? AND server_id = ?',
      whereArgs: [mangaId.trim(), serverId.trim().toLowerCase()],
    );
  }

  // ========== LIMPIEZA Y OPTIMIZACIÓN ==========

  /// Limpia el progreso de lectura de mangas que NO están guardados en la biblioteca
  /// Esto ayuda a mantener la BD optimizada eliminando datos huérfanos
  Future<int> cleanOrphanedReadingProgress() async {
    final db = await database;

    // Eliminar registros de progreso que no corresponden a mangas guardados
    final result = await db.rawDelete('''
      DELETE FROM reading_progress
      WHERE NOT EXISTS (
        SELECT 1 FROM saved_mangas
        WHERE saved_mangas.manga_id = reading_progress.manga_id
        AND saved_mangas.server_id = reading_progress.server_id
      )
    ''');

    print('🧹 Registros de progreso huérfanos eliminados: $result');
    return result;
  }

  /// Limpia capítulos descargados de mangas que NO están guardados en la biblioteca
  Future<int> cleanOrphanedDownloadedChapters() async {
    final db = await database;

    final result = await db.rawDelete('''
      DELETE FROM downloaded_chapters
      WHERE NOT EXISTS (
        SELECT 1 FROM saved_mangas
        WHERE saved_mangas.manga_id = downloaded_chapters.manga_id
        AND saved_mangas.server_id = downloaded_chapters.server_id
      )
    ''');

    print('🧹 Capítulos descargados huérfanos eliminados: $result');
    return result;
  }

  /// Limpia progreso de lectura antiguo (más de 90 días sin actualizar)
  Future<int> cleanOldReadingProgress({int daysOld = 90}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final result = await db.delete(
      'reading_progress',
      where: 'last_read_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );

    print('🧹 Registros de progreso antiguos eliminados: $result');
    return result;
  }

  /// Optimiza la base de datos (VACUUM, ANALYZE)
  Future<void> optimizeDatabase() async {
    final db = await database;

    // VACUUM libera espacio no utilizado y desfragmenta la BD
    await db.execute('VACUUM');

    // ANALYZE actualiza las estadísticas de las tablas para mejorar el rendimiento
    await db.execute('ANALYZE');

    print('✅ Base de datos optimizada (VACUUM + ANALYZE)');
  }

  /// Obtiene estadísticas de la base de datos
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    // Contar registros en cada tabla
    final savedMangasCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM saved_mangas'),
        ) ??
        0;

    final readingProgressCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM reading_progress'),
        ) ??
        0;

    final downloadedChaptersCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM downloaded_chapters'),
        ) ??
        0;

    final categoriesCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM categories'),
        ) ??
        0;

    // Contar progreso huérfano (no asociado a mangas guardados)
    final orphanedProgressCount =
        Sqflite.firstIntValue(
          await db.rawQuery('''
        SELECT COUNT(*) FROM reading_progress
        WHERE NOT EXISTS (
          SELECT 1 FROM saved_mangas
          WHERE saved_mangas.manga_id = reading_progress.manga_id
          AND saved_mangas.server_id = reading_progress.server_id
        )
      '''),
        ) ??
        0;

    return {
      'savedMangas': savedMangasCount,
      'readingProgress': readingProgressCount,
      'downloadedChapters': downloadedChaptersCount,
      'categories': categoriesCount,
      'orphanedProgress': orphanedProgressCount,
    };
  }

  /// Realiza una limpieza completa del caché
  Future<Map<String, int>> performFullCacheCleanup() async {
    print('🧹 Iniciando limpieza completa del caché...');

    final orphanedProgress = await cleanOrphanedReadingProgress();
    final orphanedChapters = await cleanOrphanedDownloadedChapters();
    final oldProgress = await cleanOldReadingProgress(daysOld: 90);

    // Optimizar la base de datos después de la limpieza
    await optimizeDatabase();

    print('✅ Limpieza completa finalizada');

    return {
      'orphanedProgress': orphanedProgress,
      'orphanedChapters': orphanedChapters,
      'oldProgress': oldProgress,
      'total': orphanedProgress + orphanedChapters + oldProgress,
    };
  }

  /// Obtiene el tamaño de la base de datos en bytes
  Future<int> getDatabaseSize() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'mangari.db');
      final file = await databaseFactory.databaseExists(path);

      if (file) {
        // Obtener tamaño usando consulta SQL
        final db = await database;
        final result = await db.rawQuery('PRAGMA page_count');
        final pageCount = Sqflite.firstIntValue(result) ?? 0;

        final pageSizeResult = await db.rawQuery('PRAGMA page_size');
        final pageSize = Sqflite.firstIntValue(pageSizeResult) ?? 4096;

        return pageCount * pageSize;
      }
      return 0;
    } catch (e) {
      print('❌ Error obteniendo tamaño de BD: $e');
      return 0;
    }
  }

  /// Obtiene estadísticas avanzadas de rendimiento
  Future<Map<String, dynamic>> getPerformanceStats() async {
    final db = await database;
    final stats = await getDatabaseStats();
    final size = await getDatabaseSize();

    // Obtener información de fragmentación
    final freelistResult = await db.rawQuery('PRAGMA freelist_count');
    final freelistCount = Sqflite.firstIntValue(freelistResult) ?? 0;

    final pageCountResult = await db.rawQuery('PRAGMA page_count');
    final pageCount = Sqflite.firstIntValue(pageCountResult) ?? 0;

    final fragmentationPercentage =
        pageCount > 0
            ? (freelistCount / pageCount * 100).toStringAsFixed(2)
            : '0.00';

    return {
      ...stats,
      'databaseSize': size,
      'databaseSizeMB': (size / (1024 * 1024)).toStringAsFixed(2),
      'fragmentationPercentage': fragmentationPercentage,
      'shouldOptimize': freelistCount > 100 || stats['orphanedProgress']! > 50,
    };
  }

  /// Realiza mantenimiento automático si es necesario
  Future<bool> autoMaintenance() async {
    try {
      final perfStats = await getPerformanceStats();
      final shouldOptimize = perfStats['shouldOptimize'] as bool;

      if (shouldOptimize) {
        print('🔧 Iniciando mantenimiento automático...');
        await performFullCacheCleanup();
        return true;
      }

      print('✅ Base de datos en buen estado, no requiere mantenimiento');
      return false;
    } catch (e) {
      print('❌ Error en mantenimiento automático: $e');
      return false;
    }
  }

  /// Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
