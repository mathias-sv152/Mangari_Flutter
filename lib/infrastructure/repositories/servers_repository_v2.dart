import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/application/services/mangadx_service.dart';

/// Repositorio de Servidores que implementa IServersRepositoryV2  
/// Maneja únicamente MangaDX como servidor activo usando el servicio de application
class ServersRepositoryV2 implements IServersRepositoryV2 {
  final MangaDxService _mangaDxService;
  late final List<ServerEntity> _servers;

  ServersRepositoryV2({
    required MangaDxService mangaDxService,
  }) : _mangaDxService = mangaDxService {
    
    // Inicializar los servidores con MangaDeX como único servidor activo
    _servers = [
      ServerEntity(
        id: 'mangadex',
        name: 'MangaDex',
        iconUrl: 'https://mangadex.dev/content/images/2021/08/icon.png',
        language: 'Es',
        baseUrl: 'https://api.mangadex.org',
        isActive: _mangaDxService.isActive,
        serviceName: _mangaDxService.serverName,
      ),
    ];
  }

  @override
  Future<List<ServerEntity>> getServers() async {
    return List.from(_servers);
  }

  @override
  Future<ServerEntity?> getServerById(String serverId) async {
    try {
      return _servers.firstWhere((server) => server.id == serverId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ServerEntity>> getActiveServers() async {
    return _servers.where((server) => server.isActive).toList();
  }

  @override
  Future<List<MangaEntity>> getMangaFromServer(String serverId, {int page = 1}) async {
    try {
      if (serverId != 'mangadex') {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      // Por ahora retornar una lista vacía
      // TODO: Implementar conversión desde el repositorio de manga
      return [];
    } catch (e) {
      throw Exception('Error al obtener manga del servidor $serverId: $e');
    }
  }

  @override
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1}) async {
    try {
      if (serverId != 'mangadex') {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      // Por ahora, devolver el mismo resultado que getMangaFromServer
      return await getMangaFromServer(serverId, page: page);
    } catch (e) {
      throw Exception('Error al buscar manga en el servidor $serverId: $e');
    }
  }

  @override
  Future<List<MangaEntity>> getAllMangaFromActiveServers({int page = 1}) async {
    final activeServers = await getActiveServers();
    List<MangaEntity> allManga = [];

    for (final server in activeServers) {
      try {
        final manga = await getMangaFromServer(server.id, page: page);
        allManga.addAll(manga);
      } catch (e) {
        // Log error pero continuar con otros servidores
        print('Error obteniendo manga de ${server.name}: $e');
      }
    }

    // Ordenar por título para mejor experiencia de usuario
    allManga.sort((a, b) => a.title.compareTo(b.title));
    
    return allManga;
  }

  /// Obtiene las imágenes de un capítulo desde el servicio MangaDX
  Future<List<String>> getChapterImagesFromServer(String serverId, String chapterId) async {
    try {
      if (serverId != 'mangadx') {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      return await _mangaDxService.getChapterImagesById(chapterId);
    } catch (e) {
      throw Exception('Error al obtener imágenes del capítulo: $e');
    }
  }
}