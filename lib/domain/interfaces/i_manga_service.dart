import 'package:mangari/domain/entities/manga_entity.dart';

/// Interfaz compartida para todos los servicios de manga
/// Define el contrato que deben cumplir todos los servidores de manga
abstract class IMangaService {
  /// Obtiene una lista de manga con paginación
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20});
  
  /// Obtiene el detalle de un manga específico
  Future<MangaEntity> getMangaDetail(String mangaId);
  
  /// Obtiene las imágenes de un capítulo
  Future<List<String>> getChapterImages(String chapterId);
  
  /// Busca manga por título
  Future<List<MangaEntity>> searchManga(String query, {int page = 1});
  
  /// Obtiene el nombre identificador del servidor
  String get serverName;
  
  /// Obtiene si el servidor está activo
  bool get isActive;
}
