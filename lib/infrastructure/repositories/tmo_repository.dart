import '../../domain/interfaces/i_tmo_repository.dart';
import 'package:http/http.dart' as http;

/// Repositorio TMO que implementa ITmoRepository
/// Maneja las peticiones HTTP a zonatmo.com específicamente para contenido HTML
class TmoRepository implements ITmoRepository {
  final String _baseUrl = "https://zonatmo.com";
  final http.Client _httpClient;

  TmoRepository(this._httpClient);

  @override
  Future<String> getManga(int page) async {
    try {
      final url = "$_baseUrl/library?_pg=1&page=$page";
      final response = await _httpClient.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }
      
      return response.body;
    } catch (error) {
      throw Exception('Error in TmoRepository getManga: $error');
    }
  }

  @override
  Future<String> getMangaDetail(String mangaLink) async {
    try {
      final response = await _httpClient.get(Uri.parse(mangaLink));
      
      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }
      
      return response.body;
    } catch (error) {
      throw Exception('Error in TmoRepository getMangaDetail: $error');
    }
  }

  @override
  Future<String> getChapterDetail(String chapterLink) async {
    try {
      // Configurar headers específicos para TMO
      final response = await _httpClient.get(
        Uri.parse(chapterLink),
        headers: {
          'Referer': 'https://zonatmo.com/',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error fetching chapter data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TmoRepository getChapterDetail: $error');
    }
  }
}