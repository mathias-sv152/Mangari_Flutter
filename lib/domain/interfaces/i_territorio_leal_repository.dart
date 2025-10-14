/// Interfaz del repositorio Territorio Leal
/// Define el contrato para interactuar con la API de territorioprotegido.xyz
abstract class ITerritorioLealRepository {
  /// Obtiene la lista de manga con paginación
  /// [page] - Número de página a obtener
  /// Retorna el HTML de la página de biblioteca
  Future<String> getMangas(int page);

  /// Obtiene los detalles de un manga específico
  /// [mangaLink] - URL completa del manga
  /// Retorna el HTML de la página de detalles del manga
  Future<String> getMangaDetail(String mangaLink);

  /// Obtiene el contenido de un capítulo
  /// [chapterLink] - URL completa del capítulo
  /// Retorna el HTML de la página del capítulo
  Future<String> getChapterImages(String chapterLink);

  /// Busca mangas por título
  /// [searchText] - Texto a buscar
  /// [page] - Número de página
  /// Retorna el HTML de la página de resultados
  Future<String> searchManga(String searchText, int page);

  /// Aplica filtros de búsqueda
  /// [filters] - Mapa de filtros aplicados
  /// [page] - Número de página
  /// Retorna el HTML de la página filtrada
  Future<String> applyFilters(Map<String, dynamic> filters, int page);
}
