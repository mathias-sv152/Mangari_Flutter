import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:mangari/application/services/uchuujin_service.dart';
import 'package:mangari/domain/interfaces/i_servers_repository_v2.dart';
import 'package:mangari/domain/interfaces/i_mangadex_reporitory.dart';
import 'package:mangari/domain/interfaces/i_tmo_repository.dart';
import 'package:mangari/domain/interfaces/i_tmo_hentai_repository.dart';
import 'package:mangari/domain/interfaces/i_hitomi_repository.dart';
import 'package:mangari/domain/interfaces/i_territorio_leal_repository.dart';

import 'package:mangari/application/services/servers_service_v2.dart';
import 'package:mangari/application/services/tmo_service.dart';
import 'package:mangari/application/services/tmo_hentai_service.dart';
import 'package:mangari/application/services/mangadex_service.dart';
import 'package:mangari/application/services/hitomi_service.dart';
import 'package:mangari/application/services/territorio_leal_service.dart';
import 'package:mangari/domain/interfaces/i_uchuujin_repository.dart';

import 'package:mangari/infrastructure/repositories/mangadex_repository.dart';
import 'package:mangari/infrastructure/repositories/servers_repository_v2.dart';
import 'package:mangari/infrastructure/repositories/tmo_repository.dart';
import 'package:mangari/infrastructure/repositories/tmo_hentai_repository.dart';
import 'package:mangari/infrastructure/repositories/hitomi_repository.dart';
import 'package:mangari/infrastructure/repositories/territorio_leal_repository.dart';
import 'package:mangari/infrastructure/client/api_client.dart';

// Importar servicios de biblioteca y descargas
import 'package:mangari/infrastructure/database/database_service.dart';
import 'package:mangari/infrastructure/repositories/uchuujin_repository.dart';
import 'package:mangari/infrastructure/services/download_service.dart';
import 'package:mangari/application/services/library_service.dart';

final GetIt getIt = GetIt.instance;

// Flag para evitar múltiples configuraciones
bool _isConfigured = false;

// Instancias globales que persisten incluso si se reconfigura el service locator
DatabaseService? _persistentDatabaseService;
DownloadService? _persistentDownloadService;
LibraryService? _persistentLibraryService;

/// Configura e inicializa todas las dependencias del sistema
void setupDependencies() {
  // Evitar configurar múltiples veces
  if (_isConfigured) {
    print('⚠️ Service Locator ya está configurado, saltando...');
    return;
  }

  print('🔧 Iniciando configuración del Service Locator...');

  // Limpiar registros previos solo la primera vez
  getIt.reset();

  try {
    print('🔧 Registrando clients...');
    // ========== CLIENTS ==========
    getIt.registerLazySingleton<http.Client>(() => http.Client());
    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(httpClient: getIt<http.Client>()),
    );

    print('🔧 Registrando repositories...');
    // ========== REPOSITORIES ==========
    getIt.registerLazySingleton<ITmoRepository>(
      () => TmoRepository(getIt<http.Client>()),
    );
    getIt.registerLazySingleton<IUchuujinRepository>(
      () => UchuujinRepository(getIt<http.Client>()),
    );
    getIt.registerLazySingleton<ITmoHentaiRepository>(
      () => TmoHentaiRepository(getIt<http.Client>()),
    );
    getIt.registerLazySingleton<IMangaDexRepository>(
      () => MangaDexRepository(getIt<http.Client>()),
    );
    getIt.registerLazySingleton<IHitomiRepository>(
      () => HitomiRepository(getIt<http.Client>()),
    );
    getIt.registerLazySingleton<ITerritorioLealRepository>(
      () => TerritorioLealRepository(getIt<http.Client>()),
    );

    print('🔧 Registrando services...');
    // ========== SERVICES (Application) ==========
    getIt.registerLazySingleton<TmoService>(
      () => TmoService(tmoRepository: getIt<ITmoRepository>()),
    );

    getIt.registerLazySingleton<UchuujinService>(
      () => UchuujinService(repository: getIt<IUchuujinRepository>()),
    );

    getIt.registerLazySingleton<TmoHentaiService>(
      () =>
          TmoHentaiService(tmoHentaiRepository: getIt<ITmoHentaiRepository>()),
    );

    getIt.registerLazySingleton<MangaDexService>(
      () => MangaDexService(getIt<IMangaDexRepository>()),
    );

    getIt.registerLazySingleton<HitomiService>(
      () => HitomiService(hitomiRepository: getIt<IHitomiRepository>()),
    );

    getIt.registerLazySingleton<TerritorioLealService>(
      () => TerritorioLealService(
        territorioLealRepository: getIt<ITerritorioLealRepository>(),
      ),
    );

    print('🔧 Registrando repositories v2...');
    // ========== REPOSITORIES V2 ==========
    getIt.registerLazySingleton<IServersRepositoryV2>(
      () => ServersRepositoryV2(
        mangaDexService: getIt<MangaDexService>(),
        tmoService: getIt<TmoService>(),
        tmoHentaiService: getIt<TmoHentaiService>(),
        hitomiService: getIt<HitomiService>(),
        territorioLealService: getIt<TerritorioLealService>(),
        uchuujinService: getIt<UchuujinService>(),
      ),
    );

    print('🔧 Registrando services v2...');
    // ========== APPLICATION SERVICES V2 ==========
    getIt.registerLazySingleton<ServersServiceV2>(
      () => ServersServiceV2(repository: getIt<IServersRepositoryV2>()),
    );

    print('🔧 Registrando servicios de biblioteca...');
    // ========== DATABASE & LIBRARY SERVICES ==========
    // Estos servicios persisten incluso si se reconfigura el service locator
    // para mantener los Streams y subscripciones activas

    _persistentDatabaseService ??= DatabaseService();
    getIt.registerSingleton<DatabaseService>(_persistentDatabaseService!);
    print('✅ DatabaseService registrado (persistente)');

    _persistentDownloadService ??= DownloadService(
      databaseService: _persistentDatabaseService!,
      serversService: getIt<ServersServiceV2>(),
    );
    getIt.registerSingleton<DownloadService>(_persistentDownloadService!);
    print('✅ DownloadService registrado (persistente)');

    _persistentLibraryService ??= LibraryService(
      databaseService: _persistentDatabaseService!,
      downloadService: _persistentDownloadService!,
    );
    getIt.registerSingleton<LibraryService>(_persistentLibraryService!);
    print(
      '✅ LibraryService registrado (persistente): hashCode=${_persistentLibraryService.hashCode}',
    );

    print('✅ Service Locator configurado correctamente');

    // Verificar que las dependencias están registradas
    _verifyDependencies();

    // Marcar como configurado
    _isConfigured = true;
    print('🔒 Service Locator marcado como configurado');
  } catch (e) {
    print('❌ Error configurando Service Locator: $e');
    _isConfigured = false; // Permitir reintentos en caso de error
    rethrow;
  }
}

/// Verifica que todas las dependencias críticas están registradas
void _verifyDependencies() {
  try {
    print('🔍 Verificando dependencias...');
    print('🔍 Service Locator: GetIt instance hashCode: ${getIt.hashCode}');

    // Verificar clients
    final client = getIt<http.Client>();
    print('✓ http.Client registrado: ${client.runtimeType}');

    // Verificar repositories
    final tmoRepo = getIt<ITmoRepository>();
    print('✓ ITmoRepository registrado: ${tmoRepo.runtimeType}');

    final mangaDexRepo = getIt<IMangaDexRepository>();
    print('✓ IMangaDexRepository registrado: ${mangaDexRepo.runtimeType}');

    final hitomiRepo = getIt<IHitomiRepository>();
    print('✓ IHitomiRepository registrado: ${hitomiRepo.runtimeType}');

    final territorioLealRepo = getIt<ITerritorioLealRepository>();
    print(
      '✓ ITerritorioLealRepository registrado: ${territorioLealRepo.runtimeType}',
    );

    // Verificar services
    final tmoService = getIt<TmoService>();
    print('✓ TmoService registrado: ${tmoService.runtimeType}');

    final mangaDexService = getIt<MangaDexService>();
    print('✓ MangaDexService registrado: ${mangaDexService.runtimeType}');

    final hitomiService = getIt<HitomiService>();
    print('✓ HitomiService registrado: ${hitomiService.runtimeType}');

    final territorioLealService = getIt<TerritorioLealService>();
    print(
      '✓ TerritorioLealService registrado: ${territorioLealService.runtimeType}',
    );

    // Verificar repository v2
    final serversRepo = getIt<IServersRepositoryV2>();
    print('✓ IServersRepositoryV2 registrado: ${serversRepo.runtimeType}');

    // Verificar service v2
    final serversService = getIt<ServersServiceV2>();
    print('✓ ServersServiceV2 registrado: ${serversService.runtimeType}');
    print('✓ ServersServiceV2 instance hashCode: ${serversService.hashCode}');

    // Verificar servicios de biblioteca
    final databaseService = getIt<DatabaseService>();
    print('✓ DatabaseService registrado: ${databaseService.runtimeType}');

    final downloadService = getIt<DownloadService>();
    print('✓ DownloadService registrado: ${downloadService.runtimeType}');

    final libraryService = getIt<LibraryService>();
    print('✓ LibraryService registrado: ${libraryService.runtimeType}');

    print('✅ Todas las dependencias verificadas correctamente');
  } catch (e) {
    print('❌ Error verificando dependencias: $e');
    rethrow;
  }
}

/// Método helper para obtener ServersServiceV2 de manera segura
ServersServiceV2? getServersServiceSafely() {
  try {
    print('🔍 getServersServiceSafely: Verificando estado...');
    print('🔍 Service Locator configurado: $_isConfigured');
    print('🔍 getServersServiceSafely: Verificando si está registrado...');

    if (getIt.isRegistered<ServersServiceV2>()) {
      print('✓ getServersServiceSafely: ServersServiceV2 está registrado');
      final service = getIt.get<ServersServiceV2>();
      print(
        '✓ getServersServiceSafely: Servicio obtenido: ${service.runtimeType}',
      );
      return service;
    } else {
      print('❌ getServersServiceSafely: ServersServiceV2 NO está registrado');
      print('❌ Algo borró las dependencias! Reconfigurar...');

      // Si las dependencias se perdieron, intentar reconfigurar
      _isConfigured = false;
      setupDependencies();

      // Intentar de nuevo
      if (getIt.isRegistered<ServersServiceV2>()) {
        return getIt.get<ServersServiceV2>();
      }

      return null;
    }
  } catch (e) {
    print('❌ Error obteniendo ServersServiceV2: $e');
    return null;
  }
}

/// Método helper para obtener LibraryService de manera segura
LibraryService? getLibraryServiceSafely() {
  try {
    print('🔍 getLibraryServiceSafely: Verificando estado...');

    if (getIt.isRegistered<LibraryService>()) {
      print('✓ getLibraryServiceSafely: LibraryService está registrado');
      final service = getIt.get<LibraryService>();
      print(
        '✓ getLibraryServiceSafely: Servicio obtenido: ${service.runtimeType}',
      );
      return service;
    } else {
      print('❌ getLibraryServiceSafely: LibraryService NO está registrado');
      print('❌ Intentando reconfigurar...');

      // Si las dependencias se perdieron, intentar reconfigurar
      _isConfigured = false;
      setupDependencies();

      // Intentar de nuevo
      if (getIt.isRegistered<LibraryService>()) {
        return getIt.get<LibraryService>();
      }

      return null;
    }
  } catch (e) {
    print('❌ Error obteniendo LibraryService: $e');
    print('Stack trace: $e');
    return null;
  }
}
