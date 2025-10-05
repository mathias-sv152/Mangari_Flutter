import '../../domain/interfaces/manga_interfaces.dart';
import '../client/api_client.dart';

class MangaDxRepository implements IMangaRepository {
  final ApiClient _apiClient;
  static const String baseUrl = 'https://api.mangadex.org';

  MangaDxRepository(this._apiClient);

  @override
  Future<Map<String, dynamic>> getManga(int page) async {
    try {
      final offset = page * 32;
      const params = 'limit=32'
          '&includes[]=cover_art'
          '&includes[]=manga'
          '&contentRating[]=safe'
          '&contentRating[]=suggestive'
          '&contentRating[]=erotica'
          '&order[createdAt]=desc'
          '&availableTranslatedLanguage[]=es-la'
          '&hasAvailableChapters=true';
      
      final endpoint = '/manga?$params&offset=$offset';
      
      final response = await _apiClient.get('$baseUrl$endpoint');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener manga: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getMangaDetail(String mangaId) async {
    try {
      final endpoint = '/manga/$mangaId';
      final response = await _apiClient.get('$baseUrl$endpoint');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener detalles del manga: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getChapters(String mangaId) async {
    try {
      const params = 'translatedLanguage[]=es-la'
          '&limit=96'
          '&includes[]=scanlation_group'
          '&includes[]=user'
          '&order[volume]=desc'
          '&order[chapter]=desc'
          '&offset=0'
          '&contentRating[]=safe'
          '&contentRating[]=suggestive'
          '&contentRating[]=erotica'
          '&contentRating[]=pornographic'
          '&includeUnavailable=0';
      
      final endpoint = '/manga/$mangaId/feed?$params';
      final response = await _apiClient.get('$baseUrl$endpoint');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener capítulos: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getChapterDetail(String chapterId) async {
    try {
      final endpoint = '/at-home/server/$chapterId?forcePort443=false';
      final response = await _apiClient.get('$baseUrl$endpoint');
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener detalles del capítulo: $e');
    }
  }
}