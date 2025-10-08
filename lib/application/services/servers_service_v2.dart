import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';

/// Servicio de aplicación para Servers V2
/// Maneja la lógica de negocio para múltiples servidores de manga
class ServersServiceV2 {
  final IServersRepositoryV2 _repository;

  ServersServiceV2({required IServersRepositoryV2 repository}) 
      : _repository = repository;

  /// Obtiene todos los servidores disponibles
  Future<List<ServerEntity>> getAllServers() async {
    try {
      final servers = await _repository.getServers();
      
      // Ordenar poniendo primero los activos
      servers.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return a.name.compareTo(b.name);
      });
      
      return servers;
    } catch (e) {
      throw Exception('Error en el servicio al obtener servidores: $e');
    }
  }

  /// Obtiene mangas de un servidor específico
  Future<List<MangaEntity>> getMangasFromServer(String serverId, {int page = 1, int limit = 20}) async {
    try {
      return await _repository.getMangasFromServer(serverId, page: page, limit: limit);
    } catch (e) {
      throw Exception('Error al obtener mangas del servidor $serverId: $e');
    }
  }

  /// Obtiene el detalle de un manga específico de un servidor
  Future<MangaEntity> getMangaDetailFromServer(String serverId, String mangaId) async {
    try {
      return await _repository.getMangaDetailFromServer(serverId, mangaId);
    } catch (e) {
      throw Exception('Error al obtener detalle del manga desde el servidor $serverId: $e');
    }
  }

  /// Obtiene las imágenes de un capítulo de un servidor específico
  Future<List<String>> getChapterImagesFromServer(String serverId, String chapterId) async {
    try {
      return await _repository.getChapterImagesFromServer(serverId, chapterId);
    } catch (e) {
      throw Exception('Error al obtener imágenes del capítulo desde el servidor $serverId: $e');
    }
  }

  /// Busca mangas en un servidor específico
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1}) async {
    try {
      if (query.trim().isEmpty) {
        return await getMangasFromServer(serverId, page: page);
      }
      return await _repository.searchMangaInServer(serverId, query, page: page);
    } catch (e) {
      throw Exception('Error al buscar mangas en el servidor $serverId: $e');
    }
  }

  
}