import 'package:mangari/domain/entities/server_entity_v2.dart';
import 'package:mangari/domain/entities/manga_entity.dart';

/// Interfaz del repositorio de Servers que maneja múltiples servicios de manga
abstract class IServersRepositoryV2 {
  /// Obtiene todos los servidores disponibles
  Future<List<ServerEntity>> getServers();
  
  /// Obtiene un servidor por su ID
  Future<ServerEntity?> getServerById(String serverId);
  
  /// Obtiene servidores activos
  Future<List<ServerEntity>> getActiveServers();
  
  /// Obtiene manga de un servidor específico
  Future<List<MangaEntity>> getMangaFromServer(String serverId, {int page = 1});
  
  /// Busca manga en un servidor específico
  Future<List<MangaEntity>> searchMangaInServer(String serverId, String query, {int page = 1});
  
  /// Obtiene manga de todos los servidores activos
  Future<List<MangaEntity>> getAllMangaFromActiveServers({int page = 1});
}