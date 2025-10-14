import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/entities/filter_entity.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/application/interfaces/i_manga_service.dart';
import 'package:mangari/application/services/tmo_service.dart';
import 'package:mangari/application/services/tmo_hentai_service.dart';
import 'package:mangari/application/services/mangadex_service.dart';
import 'package:mangari/application/services/hitomi_service.dart';
import 'package:mangari/application/services/territorio_leal_service.dart';

/// Repositorio de Servidores que implementa IServersRepositoryV2
/// Maneja MangaDex, TMO, TMO Hentai y Hitomi como servidores activos
class ServersRepositoryV2 implements IServersRepositoryV2 {
  final MangaDexService _mangaDexService;
  final TmoService _tmoService;
  final TmoHentaiService _tmoHentaiService;
  final HitomiService _hitomiService;
  final TerritorioLealService _territorioLealService;
  late final List<ServerEntity> _servers;
  late final Map<String, IMangaService> _serviceMap;

  ServersRepositoryV2({
    required MangaDexService mangaDexService,
    required TmoService tmoService,
    required TmoHentaiService tmoHentaiService,
    required HitomiService hitomiService,
    required TerritorioLealService territorioLealService,
  }) : _mangaDexService = mangaDexService,
       _tmoService = tmoService,
       _tmoHentaiService = tmoHentaiService,
       _hitomiService = hitomiService,
       _territorioLealService = territorioLealService {
    // Inicializar el mapa de servicios
    _serviceMap = {
      'mangadex': _mangaDexService,
      'tmo': _tmoService,
      'tmo_hentai': _tmoHentaiService,
      'hitomi': _hitomiService,
      'territorio_leal': _territorioLealService,
    };

    // Inicializar los servidores con MangaDex, TMO y TMO Hentai
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
      ServerEntity(
        id: 'tmo_hentai',
        name: 'TMO Hentai',
        iconUrl:
            'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcT41h_Eezrjf_r4rQJrnBPU7bk8vQHy9CidjQ&s',
        language: 'Es',
        baseUrl: 'https://tmohentai.com',
        isActive: _tmoHentaiService.isActive,
        serviceName: _tmoHentaiService.serverName,
        isAdult: true,
      ),
      ServerEntity(
        id: 'hitomi',
        name: 'Hitomi',
        iconUrl:
            'https://ltn.gold-usergeneratedcontent.net/favicon-192x192.png',
        language: 'Es',
        baseUrl: 'https://hitomi.la',
        isActive: _hitomiService.isActive,
        serviceName: _hitomiService.serverName,
        isAdult: true,
      ),
      ServerEntity(
        id: 'territorio_leal',
        name: 'Territorio Leal',
        iconUrl:
            'https://territorioleal.com/wp-content/uploads/2017/10/pngwing.com-1.png',
        language: 'Es',
        baseUrl: 'https://territorioprotegido.xyz',
        isActive: _territorioLealService.isActive,
        serviceName: _territorioLealService.serverName,
      ),
      ServerEntity(
        // servidor a implementar
        id: 'uchuujinmangas',
        name: 'Uchuujin Mangas',
        iconUrl:
            'https://uchuujinmangas.com/wp-content/uploads/2024/12/logo2.png',
        language: 'Es',
        baseUrl: 'https://uchuujinmangas.com',
        isActive: false,
      ),
    ];
  }

  @override
  Future<List<ServerEntity>> getServers() async {
    return List.from(_servers);
  }

  @override
  Future<List<MangaEntity>> getMangasFromServer(
    String serverId, {
    int page = 1,
    int limit = 20,
  }) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    return await service.getAllMangas(page: page, limit: limit);
  }

  @override
  Future<MangaEntity> getMangaDetailFromServer(
    String serverId,
    String mangaId,
  ) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    return await service.getMangaDetail(mangaId);
  }

  @override
  Future<List<String>> getChapterImagesFromServer(
    String serverId,
    String chapterId,
  ) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    return await service.getChapterImages(chapterId);
  }

  @override
  Future<List<MangaEntity>> searchMangaInServer(
    String serverId,
    String query, {
    int page = 1,
  }) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    return await service.searchManga(query, page: page);
  }

  @override
  Future<List<FilterGroupEntity>> getFiltersForServer(String serverId) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    try {
      return await service.getFilters();
    } catch (e) {
      // Si el servidor no implementa filtros, retornar lista vacía
      return [];
    }
  }

  @override
  Future<List<MangaEntity>> applyFiltersInServer(
    String serverId,
    int page,
    Map<String, dynamic> selectedFilters,
  ) async {
    final service = _serviceMap[serverId];
    if (service == null) {
      throw Exception('Servidor no encontrado: $serverId');
    }

    return await service.applyFilter(page, selectedFilters);
  }
}
