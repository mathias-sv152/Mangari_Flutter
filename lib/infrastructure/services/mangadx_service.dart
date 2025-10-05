import 'package:mangari/domain/entities/manga_entity.dart';
import 'package:mangari/domain/interfaces/i_manga_service.dart';
import 'package:mangari/infrastructure/client/api_client.dart';
import 'package:mangari/infrastructure/types/mangadx_manga_dto.dart';

/// Servicio de MangaDex que implementa IMangaService
/// Maneja las peticiones específicas a la API de MangaDex
class MangaDxService implements IMangaService {
  final ApiClient _apiClient;
  static const String _baseUrl = 'https://api.mangadex.org';

  MangaDxService({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  String get serverName => 'MangaDex';

  @override
  bool get isActive => true;

  @override
  Future<List<MangaEntity>> getAllMangas({int page = 1, int limit = 20}) async {
    try {
      final offset = (page - 1) * limit;
      
      // Construir parámetros para obtener manga en español
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        'availableTranslatedLanguage[]': 'es', // Solo manga disponible en español
        'includes[]': ['cover_art', 'author', 'artist', 'tag'],
        'order[latestUploadedChapter]': 'desc', // Ordenar por último capítulo subido
        'contentRating[]': ['safe', 'suggestive'], // Excluir contenido explícito
      };

      // Construir URL con parámetros
      final uri = Uri.parse('$_baseUrl/manga').replace(
        queryParameters: queryParams,
      );

      final response = await _apiClient.get(uri.toString());
      
      if (response == null || response['data'] == null) {
        return [];
      }

      final List<dynamic> mangaList = response['data'];
      
      return mangaList
          .map((mangaJson) => MangaDexMangaDto.fromJson(mangaJson).toEntity())
          .toList();
          
    } catch (e) {
      throw Exception('Error al obtener manga de MangaDex: $e');
    }
  }

  @override
  Future<MangaEntity> getMangaDetail(String mangaId) async {
    try {
      final queryParams = {
        'includes[]': ['cover_art', 'author', 'artist', 'tag'],
      };

      final uri = Uri.parse('$_baseUrl/manga/$mangaId').replace(
        queryParameters: queryParams,
      );

      final response = await _apiClient.get(uri.toString());
      
      if (response == null || response['data'] == null) {
        throw Exception('Manga no encontrado');
      }

      return MangaDexMangaDto.fromJson(response['data']).toEntity();
      
    } catch (e) {
      throw Exception('Error al obtener detalle del manga: $e');
    }
  }

  @override
  Future<List<String>> getChapterImages(String chapterId) async {
    try {
      // Primero obtener la información del capítulo
      final chapterResponse = await _apiClient.get('$_baseUrl/chapter/$chapterId');
      
      if (chapterResponse == null || chapterResponse['data'] == null) {
        throw Exception('Capítulo no encontrado');
      }

      final chapterData = chapterResponse['data']['attributes'];
      final hash = chapterData['hash'];
      final dataImages = List<String>.from(chapterData['data'] ?? []);
      
      // Obtener el servidor de imágenes
      final serverResponse = await _apiClient.get('$_baseUrl/at-home/server/$chapterId');
      
      if (serverResponse == null || serverResponse['baseUrl'] == null) {
        throw Exception('Servidor de imágenes no disponible');
      }

      final baseUrl = serverResponse['baseUrl'];
      
      // Construir URLs de las imágenes
      return dataImages
          .map((imageName) => '$baseUrl/data/$hash/$imageName')
          .toList();
          
    } catch (e) {
      throw Exception('Error al obtener imágenes del capítulo: $e');
    }
  }

  @override
  Future<List<MangaEntity>> searchManga(String query, {int page = 1}) async {
    try {
      final offset = (page - 1) * 20;
      
      final queryParams = {
        'title': query,
        'limit': '20',
        'offset': offset.toString(),
        'availableTranslatedLanguage[]': 'es',
        'includes[]': ['cover_art', 'author', 'artist', 'tag'],
        'order[relevance]': 'desc',
        'contentRating[]': ['safe', 'suggestive'],
      };

      final uri = Uri.parse('$_baseUrl/manga').replace(
        queryParameters: queryParams,
      );

      final response = await _apiClient.get(uri.toString());
      
      if (response == null || response['data'] == null) {
        return [];
      }

      final List<dynamic> mangaList = response['data'];
      
      return mangaList
          .map((mangaJson) => MangaDexMangaDto.fromJson(mangaJson).toEntity())
          .toList();
          
    } catch (e) {
      throw Exception('Error al buscar manga en MangaDex: $e');
    }
  }

  /// Obtiene los capítulos de un manga específico
  Future<List<Map<String, dynamic>>> getMangaChapters(String mangaId, {String language = 'es'}) async {
    try {
      final queryParams = {
        'manga': mangaId,
        'translatedLanguage[]': language,
        'order[chapter]': 'asc',
        'limit': '100',
      };

      final uri = Uri.parse('$_baseUrl/chapter').replace(
        queryParameters: queryParams,
      );

      final response = await _apiClient.get(uri.toString());
      
      if (response == null || response['data'] == null) {
        return [];
      }

      return List<Map<String, dynamic>>.from(response['data']);
      
    } catch (e) {
      throw Exception('Error al obtener capítulos: $e');
    }
  }
}