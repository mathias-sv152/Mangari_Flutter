import 'package:mangari/domain/interfaces/i_uchuujin_repository.dart';
import 'package:http/http.dart' as http;

class UchuujinRepository implements IUchuujinRepository {
  final String _baseUrl = "https://uchuujinmangas.com";
  final http.Client _httpClient;

  UchuujinRepository(this._httpClient);

  @override
  Future<String> getMangas(int page) async {
    try {
      final url = "$_baseUrl/page/$page/?s";
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in UchuujinRepository getMangas: $error');
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
      throw Exception('Error in UchuujinRepository getMangaDetail: $error');
    }
  }

  @override
  Future<String> getChapterImages(String chapterLink) async {
    try {
      final response = await _httpClient.get(Uri.parse(chapterLink));

      if (response.statusCode != 200) {
        throw Exception(
          'Error fetching chapter data: ${response.reasonPhrase}',
        );
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in UchuujinRepository getChapterImages: $error');
    }
  }

  @override
  Future<String> searchMangasByTitle(String searchText, int page) async {
    try {
      final url = "$_baseUrl/page/$page/?s=$searchText";
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception(
        'Error in UchuujinRepository searchMangasByTitle: $error',
      );
    }
  }
}
