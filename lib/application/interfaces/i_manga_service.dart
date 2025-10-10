import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/entities/filter_entity.dart';

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
  
  /// Obtiene los filtros disponibles para este servidor
  Future<List<FilterGroupEntity>> getFilters();
  
  /// Aplica filtros a la búsqueda de mangas
  /// [page] - Número de página
  /// [selectedFilters] - Mapa con los filtros seleccionados
  /// El formato del mapa depende de cada servidor, pero generalmente:
  /// {
  ///   'selectedGenres': [1, 2, 3], // Lista de IDs de géneros
  ///   'selectedType': 'manga', // Tipo de manga
  ///   'selectedStatus': 'publishing', // Estado
  ///   'orderBy': 'likes_count', // Campo de ordenamiento
  ///   'orderDir': 'desc', // Dirección de ordenamiento
  ///   'searchText': 'texto' // Texto de búsqueda opcional
  /// }
  Future<List<MangaEntity>> applyFilter(int page, Map<String, dynamic> selectedFilters);
  
  /// Prepara los parámetros de filtro según el formato del servidor
  /// Convierte el formato genérico de filtros al formato específico del servidor
  Map<String, dynamic> prepareFilterParams(Map<String, dynamic> selectedFilters);
  
  /// Obtiene el nombre identificador del servidor
  String get serverName;
  
  /// Obtiene si el servidor está activo
  bool get isActive;
}
