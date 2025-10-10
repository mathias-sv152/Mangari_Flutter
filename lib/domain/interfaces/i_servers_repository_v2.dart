import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/entities/filter_entity.dart';

/// Interfaz del repositorio de Servers que maneja múltiples servicios de manga
abstract class IServersRepositoryV2 {
  /// Obtiene todos los servidores disponibles
  Future<List<ServerEntity>> getServers();
  
  /// Obtiene mangas de un servidor específico
  Future<List<MangaEntity>> getMangasFromServer(String serverId, {int page = 1, int limit = 20});
  
  /// Obtiene el detalle de un manga específico de un servidor
  Future<MangaEntity> getMangaDetailFromServer(String serverId, String mangaId);
  
  /// Obtiene las imágenes de un capítulo de un servidor específico
  Future<List<String>> getChapterImagesFromServer(String serverId, String chapterId);
  
  /// Busca mangas en un servidor específico
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1});
  
  /// Obtiene los filtros disponibles para un servidor específico
  Future<List<FilterGroupEntity>> getFiltersForServer(String serverId);
  
  /// Aplica filtros en un servidor específico
  Future<List<MangaEntity>> applyFiltersInServer(String serverId, int page, Map<String, dynamic> selectedFilters);
}