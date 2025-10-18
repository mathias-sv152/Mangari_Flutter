import '../../domain/interfaces/i_territorio_leal_repository.dart';
import 'package:http/http.dart' as http;

/// Repositorio Territorio Leal que implementa ITerritorioLealRepository
/// Maneja las peticiones HTTP a territorioprotegido.xyz específicamente para contenido HTML
class TerritorioLealRepository implements ITerritorioLealRepository {
  final String _baseUrl = "https://territorioprotegido.xyz";
  final http.Client _httpClient;

  // Cache de cookies de sesión
  Map<String, String>? _sessionCookies;
  DateTime? _cookiesExpiration;

  TerritorioLealRepository(this._httpClient);

  // Función simplificada para extraer las cookies de sesión del login
  Future<Map<String, String>> _extractSessionCookies() async {
    try {
      // Si ya tenemos cookies válidas, las reutilizamos
      if (_sessionCookies != null &&
          _cookiesExpiration != null &&
          DateTime.now().isBefore(_cookiesExpiration!)) {
        return _sessionCookies!;
      }

      const String loginUrl = 'https://territorioprotegido.xyz/wp-login.php';

      // Cookie inicial mínima requerida
      final initialCookie = 'wordpress_test_cookie=WP Cookie check';

      // Headers mínimos necesarios
      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': initialCookie,
      };

      // Datos del formulario de login
      final body = {
        'log': 'mattdev',
        'pwd': 'z9r^ZqYri2Xk!PQH3pz0',
        'rememberme': 'forever',
        'wp-submit': 'Log In',
        'testcookie': '1',
      };

      // Realizar petición POST de login
      final response = await _httpClient.post(
        Uri.parse(loginUrl),
        headers: headers,
        body: body,
      );

      // Verificar que el login fue exitoso
      // WordPress devuelve 200 incluso si falla, pero devuelve la página de login HTML
      if (!_isLoginSuccessful(response.body)) {
        throw Exception('Login failed: Invalid credentials or session');
      }

      // Inicializar con la cookie de test
      Map<String, String> sessionCookies = {
        'wordpress_test_cookie': 'WP Cookie check',
      };

      // Extraer cookies de la respuesta
      final setCookieHeader = response.headers['set-cookie'];

      if (setCookieHeader != null) {
        _parseSetCookieHeader(setCookieHeader, sessionCookies);
      }

      // Verificar que obtuvimos las cookies de autenticación necesarias
      bool hasAuthCookies = sessionCookies.keys.any(
        (key) => key.startsWith('wordpress_logged_in_'),
      );

      if (!hasAuthCookies) {
        throw Exception('Login failed: No authentication cookies received');
      }

      // Guardar cookies en cache con expiración de 1 hora
      _sessionCookies = sessionCookies;
      _cookiesExpiration = DateTime.now().add(Duration(hours: 1));

      return sessionCookies;
    } catch (error) {
      throw Exception('Error extracting session cookies: $error');
    }
  }

  // Función para verificar si el login fue exitoso
  bool _isLoginSuccessful(String responseBody) {
    // Si la respuesta contiene elementos de la página de login, significa que falló
    final loginPageIndicators = [
      '<title>Log In',
      'body.login',
      'div#login',
      'wp-login.php',
      'lsaquo; TerritorioProtegido &#8212; WordPress',
    ];

    // Si encuentra alguno de estos indicadores, el login falló
    for (String indicator in loginPageIndicators) {
      if (responseBody.contains(indicator)) {
        return false;
      }
    }

    return true;
  }

  // Función para parsear el header Set-Cookie
  void _parseSetCookieHeader(
    String setCookieValue,
    Map<String, String> cookieMap,
  ) {
    // Dividir múltiples cookies
    List<String> cookieParts = _splitSetCookieHeader(setCookieValue);

    for (String cookiePart in cookieParts) {
      if (cookiePart.trim().isEmpty) continue;

      // Solo nos interesa el primer par key=value
      List<String> attributes = cookiePart.split(';');

      if (attributes.isNotEmpty) {
        String cookieKeyValue = attributes[0].trim();

        if (cookieKeyValue.contains('=')) {
          int equalIndex = cookieKeyValue.indexOf('=');
          String key = cookieKeyValue.substring(0, equalIndex).trim();
          String value = cookieKeyValue.substring(equalIndex + 1).trim();

          if (key.isNotEmpty) {
            cookieMap[key] = value;
          }
        }
      }
    }
  }

  // Función auxiliar para dividir correctamente múltiples cookies
  List<String> _splitSetCookieHeader(String header) {
    List<String> cookies = [];
    StringBuffer currentCookie = StringBuffer();
    List<String> parts = header.split(',');

    for (int i = 0; i < parts.length; i++) {
      String part = parts[i].trim();

      // Detectar si es una nueva cookie
      bool isNewCookie =
          part.contains('=') &&
          !part.toLowerCase().startsWith('expires=') &&
          !RegExp(r'^\d{2}[\s-]+\w+').hasMatch(part);

      if (isNewCookie && currentCookie.isNotEmpty) {
        cookies.add(currentCookie.toString());
        currentCookie.clear();
        currentCookie.write(part);
      } else {
        if (currentCookie.isNotEmpty) {
          currentCookie.write(', ');
        }
        currentCookie.write(part);
      }
    }

    if (currentCookie.isNotEmpty) {
      cookies.add(currentCookie.toString());
    }

    return cookies;
  }

  // Función auxiliar para convertir Map de cookies a string
  String _cookieMapToString(Map<String, String> cookies) {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  // Función para limpiar el cache de cookies
  void clearSessionCookies() {
    _sessionCookies = null;
    _cookiesExpiration = null;
  }

  @override
  Future<String> getMangas(int page) async {
    try {
      Map<String, String> headers = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };

      String body =
          'action=madara_load_more&page=${page - 1}&template=html%2Floop%2Fcontent&vars%5Bs%5D=';

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
      // Obtener cookies de sesión actualizadas
      final sessionCookies = await _extractSessionCookies();

      Map<String, String> headers = {
        'Cookie': _cookieMapToString(sessionCookies),
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
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

      // Verificar si la respuesta nos redirigió a la página de login
      if (_isLoginPage(response.body)) {
        // Limpiar cache y reintentar con nuevas cookies
        clearSessionCookies();

        final newCookies = await _extractSessionCookies();
        headers['Cookie'] = _cookieMapToString(newCookies);

        final retryResponse = await _httpClient.get(
          Uri.parse(chapterLink),
          headers: headers,
        );

        if (retryResponse.statusCode != 200 ||
            _isLoginPage(retryResponse.body)) {
          throw Exception(
            'Authentication failed: Unable to access chapter content',
          );
        }

        return retryResponse.body;
      }

      return response.body;
    } catch (error) {
      throw Exception(
        'Error in TerritorioLealRepository getChapterImages: $error',
      );
    }
  }

  // Función para detectar si la respuesta es la página de login
  bool _isLoginPage(String responseBody) {
    final loginPageIndicators = [
      '<title>Log In',
      'body.login',
      'div#login',
      'wp-login.php',
    ];

    // Si encuentra al menos 2 indicadores, probablemente es la página de login
    int matches = 0;
    for (String indicator in loginPageIndicators) {
      if (responseBody.contains(indicator)) {
        matches++;
        if (matches >= 2) {
          return true;
        }
      }
    }

    return false;
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

      String encodedTitle = Uri.encodeComponent(searchText);

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
      return await getMangas(page);
    } catch (error) {
      throw Exception('Error in TerritorioLealRepository applyFilters: $error');
    }
  }
}
