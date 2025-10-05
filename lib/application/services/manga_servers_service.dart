import 'package:mangari/domain/entities/manga_server_entity.dart';
import 'package:mangari/domain/interfaces/i_manga_servers_repository.dart';

/// Servicio de aplicación para Manga Servers
/// Contiene la lógica de negocio para la gestión de servidores de manga
class MangaServersService {
  final IMangaServersRepository _repository;

  MangaServersService({required IMangaServersRepository repository}) 
      : _repository = repository;

  /// Obtiene todos los servidores de manga
  Future<List<MangaServerEntity>> getAllMangaServers() async {
    try {
      final servers = await _repository.getAllMangaServers();
      
      // Ordenar por nombre para mejor experiencia de usuario
      servers.sort((a, b) => a.name.compareTo(b.name));
      
      return servers;
    } catch (e) {
      throw Exception('Error en el servicio al obtener servidores de manga: $e');
    }
  }

  /// Obtiene un servidor de manga por su ID
  Future<MangaServerEntity?> getMangaServerById(String id) async {
    try {
      if (id.isEmpty) {
        throw Exception('El ID del servidor no puede estar vacío');
      }
      
      return await _repository.getMangaServerById(id);
    } catch (e) {
      throw Exception('Error en el servicio al obtener servidor de manga: $e');
    }
  }

  /// Obtiene solo los servidores de manga activos
  Future<List<MangaServerEntity>> getActiveMangaServers() async {
    try {
      final servers = await _repository.getActiveMangaServers();
      
      // Ordenar por cantidad de manga (descendente) para mostrar los mejores primero
      servers.sort((a, b) => b.mangaCount.compareTo(a.mangaCount));
      
      return servers;
    } catch (e) {
      throw Exception('Error al obtener servidores de manga activos: $e');
    }
  }

  /// Busca servidores de manga por término de búsqueda
  Future<List<MangaServerEntity>> searchMangaServers(String query) async {
    try {
      if (query.trim().isEmpty) {
        return await getAllMangaServers();
      }
      
      final servers = await _repository.searchMangaServers(query.trim());
      
      // Ordenar resultados poniendo los activos primero
      servers.sort((a, b) {
        if (a.isActive && !b.isActive) return -1;
        if (!a.isActive && b.isActive) return 1;
        return a.name.compareTo(b.name);
      });
      
      return servers;
    } catch (e) {
      throw Exception('Error al buscar servidores de manga: $e');
    }
  }

  /// Obtiene estadísticas de los servidores
  Future<Map<String, dynamic>> getMangaServersStats() async {
    try {
      final allServers = await _repository.getAllMangaServers();
      final activeServers = allServers.where((s) => s.isActive).toList();
      
      int totalManga = allServers.fold(0, (sum, server) => sum + server.mangaCount);
      int activeManga = activeServers.fold(0, (sum, server) => sum + server.mangaCount);
      
      Set<String> allLanguages = {};
      for (var server in allServers) {
        allLanguages.addAll(server.supportedLanguages);
      }
      
      return {
        'totalServers': allServers.length,
        'activeServers': activeServers.length,
        'inactiveServers': allServers.length - activeServers.length,
        'totalManga': totalManga,
        'activeManga': activeManga,
        'supportedLanguages': allLanguages.length,
        'languages': allLanguages.toList(),
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}