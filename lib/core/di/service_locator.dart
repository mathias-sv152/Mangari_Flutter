import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/application/services/mangadx_service.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/domain/interfaces/manga_interfaces.dart';
import 'package:mangari/domain/interfaces/i_manga_service.dart' as manga_service;
import 'package:mangari/domain/interfaces/i_tmo_repository.dart';
import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/infrastructure/client/api_client.dart';
import 'package:mangari/infrastructure/repositories/servers_repository_v2.dart';
import 'package:mangari/infrastructure/repositories/mangadx_repository.dart';
import 'package:mangari/infrastructure/repositories/tmo_repository.dart';
import 'package:mangari/infrastructure/services/tmo_service.dart';

/// Service Locator para la inyección de dependencias
/// Utilizamos GetIt como contenedor de IoC
final getIt = GetIt.instance;

/// Configura todas las dependencias de la aplicación
void setupDependencies() {
  // Configuración de cliente HTTP
  getIt.registerLazySingleton<http.Client>(
    () => http.Client(),
  );

  // Configuración de cliente API
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // Repositorio de MangaDx
  getIt.registerLazySingleton<IMangaRepository>(
    () => MangaDxRepository(getIt<ApiClient>()),
  );

  // Repositorio de TMO
  getIt.registerLazySingleton<ITmoRepository>(
    () => TmoRepository(getIt<http.Client>()),
  );

  // Servicio de MangaDx de aplicación (para compatibilidad hacia atrás)
  getIt.registerLazySingleton<MangaDxService>(
    () => MangaDxService(getIt<IMangaRepository>()),
  );

  // Servicio de TMO de infraestructura
  getIt.registerLazySingleton<TmoService>(
    () => TmoService(tmoRepository: getIt<ITmoRepository>()),
  );

  // Crear un adaptador para MangaDxService que implemente manga_service.IMangaService
  getIt.registerLazySingleton<manga_service.IMangaService>(
    () => _MangaDxServiceAdapter(getIt<MangaDxService>()),
    instanceName: 'mangadex',  // Cambiar de 'mangadx' a 'mangadex' para consistencia
  );

  // Registrar TMO service como manga_service.IMangaService
  getIt.registerLazySingleton<manga_service.IMangaService>(
    () => getIt<TmoService>(),
    instanceName: 'tmo',
  );

  // Repositorio V2 que maneja servidores
  getIt.registerLazySingleton<IServersRepositoryV2>(
    () => ServersRepositoryV2(
      mangaDxService: getIt<manga_service.IMangaService>(instanceName: 'mangadex'),  // Cambiar de 'mangadx' a 'mangadex'
      tmoService: getIt<TmoService>(),
    ),
  );

  // Servicio V2 para servidores de manga
  getIt.registerLazySingleton<ServersServiceV2>(
    () => ServersServiceV2(
      repository: getIt<IServersRepositoryV2>(),
    ),
  );
}

/// Limpia todas las dependencias registradas
void resetDependencies() {
  getIt.reset();
}

/// Adaptador para MangaDxService que implementa manga_service.IMangaService
class _MangaDxServiceAdapter implements manga_service.IMangaService {
  final MangaDxService _mangaDxService;

  _MangaDxServiceAdapter(this._mangaDxService);

  @override
  String get serverName => 'MangaDx';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      // El MangaDxService original retorna MangaDetailEntity, necesitamos convertir
      final mangaDetails = await _mangaDxService.getManga(page);
      
      // Convertir MangaDetailEntity a MangaEntity
      final mangaEntities = mangaDetails.map((detail) {
        return MangaEntity(
          id: detail.id,
          title: detail.title,
          description: detail.description,
          coverImageUrl: detail.linkImage,
          authors: [detail.author],
          genres: detail.genres.map((g) => g.text).toList(),
          status: detail.status.isNotEmpty ? detail.status : detail.demography,
          serverSource: 'mangadx',
        );
      }).toList();
      
      return mangaEntities;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    // Implementación pendiente - requiere conversión de MangaDetailEntity a MangaEntity
    // TODO: Usar _mangaDxService.getMangaDetail() y convertir resultado
    throw UnimplementedError('Conversión de MangaDetailEntity a MangaEntity pendiente');
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    // Usar el método original del MangaDxService
    // TODO: Usar _mangaDxService.getChapterImages()
    throw UnimplementedError('Implementación pendiente');
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    // Implementación pendiente
    // TODO: Implementar usando _mangaDxService y convertir resultados
    return [];
  }
}