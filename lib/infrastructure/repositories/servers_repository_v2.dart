import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/domain/interfaces/i_manga_service.dart';
import 'package:mangari/infrastructure/services/tmo_service.dart';

/// Repositorio de Servidores que implementa IServersRepositoryV2  
/// Maneja únicamente MangaDX como servidor activo usando el servicio de application
class ServersRepositoryV2 implements IServersRepositoryV2 {
  final IMangaService _mangaDxService;
  final TmoService _tmoService;
  late final List<ServerEntity> _servers;
  late final Map<String, IMangaService> _serviceMap;

  ServersRepositoryV2({
    required IMangaService mangaDxService,
    required TmoService tmoService,
  }) : _mangaDxService = mangaDxService,
       _tmoService = tmoService {
    
    // Inicializar el mapa de servicios
    _serviceMap = {
      'mangadex': _mangaDxService,  // Cambiar de 'mangadx' a 'mangadex' para consistencia
      'tmo': _tmoService,
    };

    // Inicializar los servidores con MangaDx y TMO
    _servers = [
      ServerEntity(
        id: 'mangadex',  // Cambiar de 'mangadx' a 'mangadex' para consistencia
        name: 'MangaDex',
        iconUrl: 'https://mangadex.dev/content/images/2021/08/icon.png',
        language: 'Es',
        baseUrl: 'https://api.mangadex.org',
        isActive: _mangaDxService.isActive,
        serviceName: _mangaDxService.serverName,
      ),
      ServerEntity(
        id: 'tmo',
        name: 'TuMangaOnline',
        iconUrl: 'https://zonatmo.com/logo.png',
        language: 'Es',
        baseUrl: 'https://zonatmo.com',
        isActive: _tmoService.isActive,
        serviceName: _tmoService.serverName,
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
      final service = _serviceMap[serverId];
      if (service == null) {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      return await service.getAllMangas(page: page, limit: 20);
    } catch (e) {
      throw Exception('Error al obtener manga del servidor $serverId: $e');
    }
  }

  @override
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1}) async {
    try {
      final service = _serviceMap[serverId];
      if (service == null) {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      return await service.searchManga(query, page: page);
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

  /// Obtiene las imágenes de un capítulo desde el servicio correspondiente
  Future<List<String>> getChapterImagesFromServer(String serverId, String chapterId) async {
    try {
      final service = _serviceMap[serverId];
      if (service == null) {
        throw Exception('Servidor no soportado: $serverId');
      }

      final server = await getServerById(serverId);
      if (server == null || !server.isActive) {
        throw Exception('El servidor $serverId no está disponible');
      }

      return await service.getChapterImages(chapterId);
    } catch (e) {
      throw Exception('Error al obtener imágenes del capítulo: $e');
    }
  }
}