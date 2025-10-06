import 'package:get_it/get_it.dart';
import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/application/services/mangadx_service.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/domain/interfaces/manga_interfaces.dart';
import 'package:mangari/infrastructure/client/api_client.dart';
import 'package:mangari/infrastructure/repositories/servers_repository_v2.dart';
import 'package:mangari/infrastructure/repositories/mangadx_repository.dart';

/// Service Locator para la inyección de dependencias
/// Utilizamos GetIt como contenedor de IoC
final getIt = GetIt.instance;

/// Configura todas las dependencias de la aplicación
void setupDependencies() {
  // Configuración de cliente API
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // Repositorio de MangaDx
  getIt.registerLazySingleton<IMangaRepository>(
    () => MangaDxRepository(getIt<ApiClient>()),
  );

  // Servicio de MangaDx de aplicación
  getIt.registerLazySingleton<MangaDxService>(
    () => MangaDxService(getIt<IMangaRepository>()),
  );

  // Repositorio V2 que maneja servidores
  getIt.registerLazySingleton<IServersRepositoryV2>(
    () => ServersRepositoryV2(
      mangaDxService: getIt<MangaDxService>(),
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