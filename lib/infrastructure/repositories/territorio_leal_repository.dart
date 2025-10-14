import '../../domain/interfaces/i_territorio_leal_repository.dart';
import 'package:http/http.dart' as http;

/// Repositorio Territorio Leal que implementa ITerritorioLealRepository
/// Maneja las peticiones HTTP a territorioprotegido.xyz específicamente para contenido HTML
class TerritorioLealRepository implements ITerritorioLealRepository {
  final String _baseUrl = "https://territorioprotegido.xyz";
  final http.Client _httpClient;

  TerritorioLealRepository(this._httpClient);

  @override
  Future<String> getMangas(int page) async {
    try {
      // Headers requeridos para las peticiones AJAX
      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

      // Cuerpo de la solicitud para cargar más contenido
      String body =
          'action=madara_load_more&page=${page - 1}&template=html%2Floop%2Fcontent&vars%5Bs%5D=';

      // Hacer la solicitud POST al endpoint AJAX
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/wp-admin/admin-ajax.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Error fetching data: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TerritorioLealRepository getMangas: $error');
    }
  }

  @override
  Future<String> getMangaDetail(String mangaLink) async {
    try {
      // Extraer el título formateado del enlace del manga
      String formattedTitle = '';

      if (mangaLink.contains('/manga/')) {
        Uri uri = Uri.parse(mangaLink);
        List<String> segments = uri.pathSegments;

        int mangaIndex = segments.indexOf('manga');
        if (mangaIndex != -1 && mangaIndex + 1 < segments.length) {
          formattedTitle = segments[mangaIndex + 1];
        }
      }

      if (formattedTitle.isEmpty) {
        throw Exception('No se pudo extraer el título del enlace: $mangaLink');
      }

      // Construir la URL para obtener los capítulos
      String url = '$_baseUrl/manga/$formattedTitle/ajax/chapters/';

      final response = await _httpClient.post(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          'Error fetching manga detail: ${response.reasonPhrase}',
        );
      }

      return response.body;
    } catch (error) {
      throw Exception(
        'Error in TerritorioLealRepository getMangaDetail: $error',
      );
    }
  }

  @override
  Future<String> getChapterImages(String chapterLink) async {
    try {
      Map<String, String> headers = {
        'Cookie':
            'dsq__u=6kpqg391lp6ul0; dsq__s=6kpqg391lp6ul0; _lc2_fpi=19fb870bf9c2--01k00xxc9qhg13newqdp1xcyk9; _li_ss=CgA; PHPSESSID=20c348361439ddf8dc7651202a53ec20; wordpress_test_cookie=WP%20Cookie%20check; _lscache_vary=2744104b3a7516ad0baebaf41874235f; wordpress_logged_in_7daa14b9647b5a0cee4beb01ccc2c9a1=mattdev%7C1761613832%7CP5nR8hg6wXPasSJ8ixdRn72BzBGFI28kbcOrY1dRmDz%7Cdb2fd4f7dd5b126bf7786d9d502274f4c50f5c33dd11e71f89ea0f041fa13564',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Referer': '$_baseUrl/',
      };

      final response = await _httpClient.get(
        Uri.parse(chapterLink),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error fetching chapter images: ${response.reasonPhrase}',
        );
      }

      return response.body;
    } catch (error) {
      throw Exception(
        'Error in TerritorioLealRepository getChapterImages: $error',
      );
    }
  }

  @override
  Future<String> searchManga(String searchText, int page) async {
    try {
      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

      // Codificar el texto de búsqueda
      String encodedTitle = Uri.encodeComponent(searchText);

      // Cuerpo de la solicitud con el término de búsqueda
      String body =
          'action=madara_load_more&page=${page - 1}&template=html%2Floop%2Fcontent&vars%5Bs%5D=$encodedTitle';

      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/wp-admin/admin-ajax.php'),
        headers: headers,
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Error searching manga: ${response.reasonPhrase}');
      }

      return response.body;
    } catch (error) {
      throw Exception('Error in TerritorioLealRepository searchManga: $error');
    }
  }

  @override
  Future<String> applyFilters(Map<String, dynamic> filters, int page) async {
    try {
      // Por ahora retornamos los mangas normales hasta implementar filtros específicos
      return await getMangas(page);
    } catch (error) {
      throw Exception('Error in TerritorioLealRepository applyFilters: $error');
    }
  }
}
