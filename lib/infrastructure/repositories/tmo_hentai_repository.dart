import '../../domain/interfaces/i_tmo_hentai_repository.dart';
import 'package:http/http.dart' as http;

/// Repositorio TMO Hentai que implementa ITmoHentaiRepository
/// Maneja las peticiones HTTP a tmohentai.com específicamente para contenido HTML
class TmoHentaiRepository implements ITmoHentaiRepository {
  final String _baseUrl = "https://tmohentai.com";
  final http.Client _httpClient;

  TmoHentaiRepository(this._httpClient);

  @override
  Future<String> getMangas(int page) async {
    try {
      final url =
          "$_baseUrl/section/all?view=thumbnails&order=popularity&order-dir=desc&search%5BsearchText%5D=&search%5BsearchBy%5D=name&type=all&page=$page";
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TmoHentaiRepository getMangas: $error');
    }
  }

  @override
  Future<String> getMangaDetail(String mangaLink) async {
    try {
      final response = await _httpClient.get(Uri.parse(mangaLink.trim()));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TmoHentaiRepository getMangaDetail: $error');
    }
  }

  @override
  Future<String> getChapterImages(String chapterLink) async {
    try {
      // Configurar headers específicos para TMO Hentai
      final response = await _httpClient.get(
        Uri.parse(chapterLink.trim()),
        headers: {'Referer': 'https://tmohentai.com/'},
      );

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TmoHentaiRepository getChapterImages: $error');
    }
  }

  @override
  Future<String> searchMangasByTitle(String searchText, int page) async {
    try {
      final encodedQuery = Uri.encodeComponent(searchText);
      final url =
          "$_baseUrl/section/all?view=thumbnails&order=popularity&order-dir=desc&search%5BsearchText%5D=$encodedQuery&search%5BsearchBy%5D=name&type=all&page=$page";
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception(
        'Error in TmoHentaiRepository searchMangasByTitle: $error',
      );
    }
  }

  @override
  Future<String> applyFilter({
    required int page,
    required List<int> selectedGenres,
    String? orderBy,
    String? orderDir,
    String? searchText,
  }) async {
    try {
      // Construir la URL base
      String baseUrl = "$_baseUrl/section/all?view=thumbnails&page=$page";

      // Añadir parámetros de búsqueda si existe searchText
      if (searchText != null && searchText.isNotEmpty) {
        final encodedQuery = Uri.encodeComponent(searchText);
        baseUrl +=
            '&search%5BsearchText%5D=$encodedQuery&search%5BsearchBy%5D=name&type=all';
      }

      // Añadir parámetro de ordenamiento
      if (orderBy != null && orderBy.isNotEmpty) {
        baseUrl += '&order=$orderBy';
      } else {
        baseUrl += '&order=popularity';
      }

      // Añadir dirección de ordenamiento
      if (orderDir != null && orderDir.isNotEmpty) {
        baseUrl += '&order-dir=$orderDir';
      } else {
        baseUrl += '&order-dir=desc';
      }

      // Añadir géneros seleccionados
      if (selectedGenres.isNotEmpty) {
        final genresQuery = selectedGenres
            .map((genre) => 'genders[]=$genre')
            .join('&');
        baseUrl += '&$genresQuery';
      }

      final response = await _httpClient.get(Uri.parse(baseUrl));

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TmoHentaiRepository applyFilter: $error');
    }
  }
}
