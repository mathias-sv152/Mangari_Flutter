/// Interfaz del repositorio TMO (TuMangaOnline)
/// Define el contrato para interactuar con la API de zonatmo.com
abstract class ITmoRepository {
  /// Obtiene la lista de manga con paginación
  /// [page] - Número de página a obtener
  /// Retorna el HTML de la página de biblioteca
  Future<String> getManga(int page);
  
  /// Obtiene los detalles de un manga específico
  /// [mangaLink] - URL completa del manga
  /// Retorna el HTML de la página de detalles del manga
  Future<String> getMangaDetail(String mangaLink);
  
  /// Obtiene el contenido de un capítulo
  /// [chapterLink] - URL completa del capítulo
  /// Retorna el HTML de la página del capítulo
  Future<String> getChapterDetail(String chapterLink);
}