import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente HTTP para realizar peticiones a la API
class ApiClient {
  final http.Client httpClient;

  ApiClient({
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Realiza una petición GET
  Future<dynamic> get(String fullUrl) async {
    try {
      final url = Uri.parse(fullUrl);
      final response = await httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en petición GET: $e');
    }
  }

  /// Realiza una petición POST
  Future<dynamic> post(String fullUrl, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse(fullUrl);
      final response = await httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en petición POST: $e');
    }
  }

  /// Realiza una petición PUT
  Future<dynamic> put(String fullUrl, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse(fullUrl);
      final response = await httpClient.put(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en petición PUT: $e');
    }
  }

  /// Realiza una petición DELETE
  Future<dynamic> delete(String fullUrl) async {
    try {
      final url = Uri.parse(fullUrl);
      final response = await httpClient.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en petición DELETE: $e');
    }
  }

  /// Maneja la respuesta HTTP
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Cierra el cliente
  void dispose() {
    httpClient.close();
  }
}
