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

  /// Obtiene solo los servidores activos
  Future<List<ServerEntity>> getActiveServers() async {
    try {
      final servers = await _repository.getActiveServers();
      
      // Ordenar por nombre
      servers.sort((a, b) => a.name.compareTo(b.name));
      
      return servers;
    } catch (e) {
      throw Exception('Error al obtener servidores activos: $e');
    }
  }

  /// Obtiene un servidor por su ID
  Future<ServerEntity?> getServerById(String serverId) async {
    try {
      if (serverId.isEmpty) {
        throw Exception('El ID del servidor no puede estar vacío');
      }
      
      return await _repository.getServerById(serverId);
    } catch (e) {
      throw Exception('Error al obtener servidor: $e');
    }
  }

  /// Obtiene manga de un servidor específico
  Future<List<MangaEntity>> getMangaFromServer(String serverId, {int page = 1}) async {
    try {
      if (serverId.isEmpty) {
        throw Exception('El ID del servidor no puede estar vacío');
      }
      
      final manga = await _repository.getMangaFromServer(serverId, page: page);
      
      // Validar que no haya manga duplicados por ID
      final uniqueManga = <String, MangaEntity>{};
      for (final m in manga) {
        uniqueManga[m.id] = m;
      }
      
      return uniqueManga.values.toList();
    } catch (e) {
      throw Exception('Error al obtener manga del servidor: $e');
    }
  }

  /// Busca manga en un servidor específico
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1}) async {
    try {
      if (serverId.isEmpty) {
        throw Exception('El ID del servidor no puede estar vacío');
      }
      
      if (query.trim().isEmpty) {
        throw Exception('La consulta de búsqueda no puede estar vacía');
      }
      
      return await _repository.searchMangaInServer(serverId, query.trim(), page: page);
    } catch (e) {
      throw Exception('Error al buscar manga: $e');
    }
  }

  /// Obtiene manga de todos los servidores activos
  Future<List<MangaEntity>> getAllMangaFromActiveServers({int page = 1}) async {
    try {
      final manga = await _repository.getAllMangaFromActiveServers(page: page);
      
      // Remover duplicados basado en título y servidor de origen
      final uniqueManga = <String, MangaEntity>{};
      for (final m in manga) {
        final key = '${m.title.toLowerCase()}_${m.serverSource}';
        uniqueManga[key] = m;
      }
      
      final result = uniqueManga.values.toList();
      
      // Ordenar por popularidad/rating si está disponible, sino por título
      result.sort((a, b) {
        if (a.rating != null && b.rating != null) {
          return b.rating!.compareTo(a.rating!);
        }
        return a.title.compareTo(b.title);
      });
      
      return result;
    } catch (e) {
      throw Exception('Error al obtener manga de servidores activos: $e');
    }
  }

  /// Obtiene estadísticas de los servidores
  Future<Map<String, dynamic>> getServersStats() async {
    try {
      final allServers = await _repository.getServers();
      final activeServers = await _repository.getActiveServers();
      
      // Intentar obtener conteo de manga de servidores activos
      int totalMangaCount = 0;
      final Map<String, int> mangaByServer = {};
      
      for (final server in activeServers) {
        try {
          final manga = await _repository.getMangaFromServer(server.id, page: 1);
          mangaByServer[server.name] = manga.length;
          totalMangaCount += manga.length;
        } catch (e) {
          mangaByServer[server.name] = 0;
        }
      }
      
      return {
        'totalServers': allServers.length,
        'activeServers': activeServers.length,
        'inactiveServers': allServers.length - activeServers.length,
        'totalMangaCount': totalMangaCount,
        'mangaByServer': mangaByServer,
        'serverNames': allServers.map((s) => s.name).toList(),
        'activeServerNames': activeServers.map((s) => s.name).toList(),
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  /// Busca manga en todos los servidores activos
  Future<List<MangaEntity>> searchInAllActiveServers(String query, {int page = 1}) async {
    try {
      if (query.trim().isEmpty) {
        return await getAllMangaFromActiveServers(page: page);
      }
      
      final activeServers = await getActiveServers();
      List<MangaEntity> allResults = [];
      
      for (final server in activeServers) {
        try {
          final results = await searchMangaInServer(server.id, query, page: page);
          allResults.addAll(results);
        } catch (e) {
          // Log error pero continuar con otros servidores
          print('Error buscando en ${server.name}: $e');
        }
      }
      
      // Remover duplicados y ordenar por relevancia
      final uniqueResults = <String, MangaEntity>{};
      for (final manga in allResults) {
        final key = '${manga.title.toLowerCase()}_${manga.serverSource}';
        if (!uniqueResults.containsKey(key) || 
            (manga.rating != null && manga.rating! > (uniqueResults[key]?.rating ?? 0))) {
          uniqueResults[key] = manga;
        }
      }
      
      final result = uniqueResults.values.toList();
      
      // Ordenar por relevancia (título que contenga la query primero)
      result.sort((a, b) {
        final queryLower = query.toLowerCase();
        final aContains = a.title.toLowerCase().contains(queryLower);
        final bContains = b.title.toLowerCase().contains(queryLower);
        
        if (aContains && !bContains) return -1;
        if (!aContains && bContains) return 1;
        
        // Si ambos contienen o no contienen, ordenar por rating
        if (a.rating != null && b.rating != null) {
          return b.rating!.compareTo(a.rating!);
        }
        
        return a.title.compareTo(b.title);
      });
      
      return result;
    } catch (e) {
      throw Exception('Error al buscar en todos los servidores: $e');
    }
  }
}