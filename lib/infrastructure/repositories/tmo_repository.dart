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

  @override
  Future<String> searchMangasByTitle(String searchText, int page) async {
    try {
      final encodedQuery = Uri.encodeComponent(searchText);
      final url = "$_baseUrl/library?order_item=likes_count&order_dir=desc&title=$encodedQuery&_pg=1&page=$page&filter_by=title&demography=&translation_status=&webcomic=&yonkoma=&amateur=&erotic=";
      
      final response = await _httpClient.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Error searching mangas: ${response.reasonPhrase}');
      }
      
      return response.body;
    } catch (error) {
      throw Exception('Error in TmoRepository searchMangasByTitle: $error');
    }
  }

  @override
  Future<String> applyFilter({
    required int page,
    required List<int> selectedGenres,
    String? selectedType,
    String? selectedStatus,
    String? orderBy,
    String? orderDir,
    String? searchText,
  }) async {
    try {
      // Construir la URL base para el filtro
      String baseUrl = '$_baseUrl/library?';

      // Añadir parámetros de ordenamiento
      baseUrl += 'order_item=${orderBy ?? 'likes_count'}&order_dir=${orderDir ?? 'desc'}';

      // Añadir parámetros de búsqueda si existe searchText
      if (searchText != null && searchText.isNotEmpty) {
        final encodedQuery = Uri.encodeComponent(searchText);
        baseUrl += '&title=$encodedQuery';
      } else {
        baseUrl += '&title=';
      }

      // Añadir página y otros parámetros comunes
      baseUrl += '&_pg=1&page=$page';
      baseUrl += '&filter_by=title&demography=&translation_status=&webcomic=&yonkoma=&amateur=&erotic=';

      // Añadir géneros seleccionados
      if (selectedGenres.isNotEmpty) {
        final genresQuery = selectedGenres.map((genre) => 'genders[]=$genre').join('&');
        baseUrl += '&$genresQuery';
      }

      // Añadir tipo seleccionado
      if (selectedType != null && selectedType.isNotEmpty) {
        baseUrl += '&type=$selectedType';
      }

      // Añadir estado seleccionado
      if (selectedStatus != null && selectedStatus.isNotEmpty) {
        baseUrl += '&status=$selectedStatus';
      }

      final response = await _httpClient.get(Uri.parse(baseUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Error applying filters: ${response.reasonPhrase}');
      }
      
      return response.body;
    } catch (error) {
      throw Exception('Error in TmoRepository applyFilter: $error');
    }
  }
}