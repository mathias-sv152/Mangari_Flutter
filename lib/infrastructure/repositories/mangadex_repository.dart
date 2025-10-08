import 'dart:convert';

import 'package:http/http.dart';
import 'package:mangari/domain/interfaces/i_mangadex_reporitory.dart';
import '../client/api_client.dart';

class MangaDexRepository implements IMangaDexRepository {
  final Client _apiClient;
  static const String baseUrl = 'https://api.mangadex.org';

  MangaDexRepository(this._apiClient);

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
      final url ='$baseUrl$endpoint';
      final response = await _apiClient.get(Uri.parse(url));
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener manga: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getMangaDetail(String mangaId) async {
    try {
      final endpoint = '/manga/$mangaId';
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _apiClient.get(url);
      return json.decode(response.body) as Map<String, dynamic>;
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
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _apiClient.get(url);
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener capítulos: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getChapterDetail(String chapterId) async {
    try {
      final endpoint = '/at-home/server/$chapterId?forcePort443=false';
      final url = Uri.parse('$baseUrl$endpoint');
      final response = await _apiClient.get(url);
      return json.decode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error al obtener detalles del capítulo: $e');
    }
  }
}