import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/application/interfaces/i_manga_service.dart';
import 'package:mangari/application/services/tmo_service.dart';
import 'package:mangari/application/services/mangadex_service.dart';

/// Repositorio de Servidores que implementa IServersRepositoryV2  
/// Maneja únicamente MangaDex como servidor activo usando el servicio de application
class ServersRepositoryV2 implements IServersRepositoryV2 {
  final MangaDexService _mangaDexService;
  final TmoService _tmoService;
  late final List<ServerEntity> _servers;
  late final Map<String, IMangaService> _serviceMap;

  ServersRepositoryV2({
    required MangaDexService mangaDexService,
    required TmoService tmoService,
  }) : _mangaDexService = mangaDexService,
       _tmoService = tmoService {

    // Inicializar el mapa de servicios
    _serviceMap = {
      'mangadex': _mangaDexService,
      'tmo': _tmoService,
    };

    // Inicializar los servidores con MangaDex y TMO
    _servers = [
      ServerEntity(
        id: 'mangadex',
        name: 'MangaDex',
        iconUrl: 'https://mangadex.dev/content/images/2021/08/icon.png',
        language: 'Es',
        baseUrl: 'https://api.mangadex.org',
        isActive: _mangaDexService.isActive,
        serviceName: _mangaDexService.serverName,
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
  Future<List<MangaEntity>> getMangasFromServer(String serverId, {int page = 1, int limit = 20}) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }
    
    return await service.getAllMangas(page: page, limit: limit);
  }

  @override
  Future<MangaEntity> getMangaDetailFromServer(String serverId, String mangaId) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }
    
    return await service.getMangaDetail(mangaId);
  }

  @override
  Future<List<String>> getChapterImagesFromServer(String serverId, String chapterId) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }
    
    return await service.getChapterImages(chapterId);
  }

  @override
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1}) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }
    
    return await service.searchManga(query, page: page);
  }
}