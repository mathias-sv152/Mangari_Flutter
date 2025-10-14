/// Interfaz del repositorio TMO Hentai
/// Define el contrato para interactuar con la API de tmohentai.com
abstract class ITmoHentaiRepository {
  /// Obtiene la lista de manga hentai con paginación
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
  Future<String> searchMangasByTitle(String searchText, int page);

  /// Aplica filtros a la búsqueda de mangas
  /// [page] - Número de página
  /// [selectedGenres] - Lista de IDs de géneros seleccionados
  /// [orderBy] - Campo por el cual ordenar
  /// [orderDir] - Dirección del ordenamiento (asc, desc)
  /// [searchText] - Texto opcional para búsqueda combinada con filtros
  /// Retorna el HTML de la página de resultados filtrados
  Future<String> applyFilter({
    required int page,
    required List<int> selectedGenres,
    String? orderBy,
    String? orderDir,
    String? searchText,
  });
}
