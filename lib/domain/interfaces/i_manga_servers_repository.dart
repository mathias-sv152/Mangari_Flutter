import 'package:mangari/domain/entities/manga_server_entity.dart';

/// Interface del repositorio de Manga Servers (Capa de Dominio)
/// Define el contrato que debe cumplir cualquier implementación del repositorio
abstract class IMangaServersRepository {
  /// Obtiene todos los servidores de manga disponibles
  Future<List<MangaServerEntity>> getAllMangaServers();
  
  /// Obtiene un servidor de manga por su ID
  Future<MangaServerEntity?> getMangaServerById(String id);
  
  /// Obtiene servidores de manga activos
  Future<List<MangaServerEntity>> getActiveMangaServers();
  
  /// Busca servidores de manga por nombre
  Future<List<MangaServerEntity>> searchMangaServers(String query);
}